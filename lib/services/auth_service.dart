import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

import 'organization_service.dart';
import 'fcm_service.dart';

enum AccountType {
  general,
  enterpriseAdmin,
  enterpriseEmployee,
}

extension AccountTypeX on AccountType {
  String get wireValue {
    switch (this) {
      case AccountType.general:
        return 'general';
      case AccountType.enterpriseAdmin:
        return 'enterprise_admin';
      case AccountType.enterpriseEmployee:
        return 'enterprise_employee';
    }
  }
}

class AuthService {
  static final Random _random = Random.secure();
  static final Map<String, _LoginAttemptWindow> _loginAttemptWindows =
      <String, _LoginAttemptWindow>{};
  static final Map<String, _RegistrationAttemptWindow>
      _registrationAttemptWindows = <String, _RegistrationAttemptWindow>{};

  static const int _maxFailedLoginAttempts = 5;
  static const int _maxFailedRegistrationAttempts = 3;
  static const Duration _loginAttemptWindowDuration = Duration(minutes: 15);
  static const Duration _registrationAttemptWindowDuration = Duration(hours: 1);

  static FirebaseAuth? _authOverride;

  @visibleForTesting
  static set auth(FirebaseAuth auth) => _authOverride = auth;

  static FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  static User? _testCurrentUser;

  static const Set<String> _invalidSessionAuthCodes = {
    'user-not-found',
    'user-disabled',
    'invalid-user-token',
    'user-token-expired',
  };

  @visibleForTesting
  static set testCurrentUser(User? user) => _testCurrentUser = user;

  @visibleForTesting
  static bool canAttemptLoginForTesting(
    String email, {
    DateTime? now,
  }) {
    return _canAttemptLogin(email, now: now);
  }

  @visibleForTesting
  static void recordFailedLoginAttemptForTesting(
    String email, {
    DateTime? now,
  }) {
    _recordFailedLoginAttempt(email, now: now);
  }

  @visibleForTesting
  static void resetLoginAttemptLimiterForTesting() {
    _loginAttemptWindows.clear();
  }

  @visibleForTesting
  static bool canAttemptRegistrationForTesting(
    String email, {
    DateTime? now,
  }) {
    return _canAttemptRegistration(email, now: now);
  }

  @visibleForTesting
  static void recordFailedRegistrationAttemptForTesting(
    String email, {
    DateTime? now,
  }) {
    _recordFailedRegistrationAttempt(email, now: now);
  }

  @visibleForTesting
  static void resetRegistrationAttemptLimiterForTesting() {
    _registrationAttemptWindows.clear();
  }

  // ================== REGISTER ==================
  static Future<void> register({
    required String email,
    required String password,
    String? fullName,
    String? documentType,
    String? documentNumber,
    String? country,
    String? city,
    AccountType accountType = AccountType.general,
    String? organizationName,
    String? organizationSector,
    int? seatsRequested,
    String? organizationId,
  }) async {
    if (!_canAttemptRegistration(email)) {
      throw Exception(
        'Demasiados intentos de registro para este correo. Intenta de nuevo en 1 hora.',
      );
    }

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        throw Exception('Usuario no creado');
      }
      if (fullName != null) {
        await user.updateDisplayName(fullName);
      }
      // Guardar datos en Firestore
      await _saveUserData(
        uid: user.uid,
        email: email,
        fullName: fullName,
        documentType: documentType,
        documentNumber: documentNumber,
        country: country,
        city: city,
        accountType: accountType,
      );

      try {
        await _ensureOrbitNumberAssigned(
          firestore: FirebaseFirestore.instance,
          uid: user.uid,
        );
      } catch (e, st) {
        // Evita bloquear el onboarding por fallos transitorios (App Check/red).
        debugPrint(
            'Registro completado con provisión parcial de OrbitNumber: $e\n$st');
      }

      await _provisionOrganizationAccess(
        uid: user.uid,
        accountType: accountType,
        organizationName: organizationName,
        organizationSector: organizationSector,
        seatsRequested: seatsRequested,
        organizationId: organizationId,
      );

      // Save FCM token now that the Firestore profile document exists.
      await FCMService.saveCurrentToken();
      _clearFailedRegistrationAttempts(email);
    } on FirebaseAuthException catch (e) {
      if (_shouldCountAsFailedRegistration(e.code)) {
        _recordFailedRegistrationAttempt(email);
      }
      throw Exception(_firebaseError(e.code, isRegistration: true));
    }
  }

  static Future<void> _provisionOrganizationAccess({
    required String uid,
    required AccountType accountType,
    String? organizationName,
    String? organizationSector,
    int? seatsRequested,
    String? organizationId,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(uid);

    if (accountType == AccountType.general) {
      return;
    }

    if (accountType == AccountType.enterpriseAdmin) {
      final seats = (seatsRequested ?? 1).clamp(1, 50000);
      final orgId = await OrganizationService.createOrganizationForAdmin(
        adminUid: uid,
        organizationName: organizationName ?? '',
        sector: organizationSector ?? 'empresa',
        seatsPurchased: seats,
      );

      await userRef.set({
        'organizationId': orgId,
        'organizationRole': 'admin',
        'organizationSector': (organizationSector ?? 'empresa').toLowerCase(),
      }, SetOptions(merge: true));
      return;
    }

    final orgId = (organizationId ?? '').trim();
    if (orgId.isEmpty) {
      throw Exception('Debes indicar el ID de organización para empleados');
    }

    await OrganizationService.joinOrganizationAsEmployee(
        orgId: orgId, uid: uid);
    await userRef.set({
      'organizationId': orgId,
      'organizationRole': 'employee',
    }, SetOptions(merge: true));
  }

  static Future<void> _ensureOrbitNumberAssigned({
    required FirebaseFirestore firestore,
    required String uid,
  }) async {
    final userRef = firestore.collection('users').doc(uid);

    // Aumentar reintentos a 10 con backoff exponencial
    for (var attempt = 0; attempt < 10; attempt++) {
      await _getOrCreateOrbitNumber(firestore: firestore, uid: uid);

      final snap = await userRef.get();
      final orbitNumber = (snap.data()?['orbitNumber'] as String?)?.trim();
      if (orbitNumber != null && orbitNumber.isNotEmpty) {
        return;
      }

      // Backoff exponencial: 300ms, 600ms, 1.2s, 2.4s (máximo 5s)
      final delayMs = (300 * (1 << (attempt ~/ 2))).clamp(0, 5000);
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }

    throw Exception(
      'No se pudo asignar el numero Orbit. Verifica reglas de Firestore y conexión de red.',
    );
  }

  static Future<void> _saveUserData({
    required String uid,
    required String email,
    String? fullName,
    String? documentType,
    String? documentNumber,
    String? country,
    String? city,
    AccountType accountType = AccountType.general,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final currentUser = _auth.currentUser;
    final userRef = firestore.collection('users').doc(uid);

    // Ensure the write is done with an authenticated user tied to this UID.
    if (currentUser == null) {
      throw Exception(
          'No hay sesión activa para guardar el perfil en Firestore');
    }
    if (currentUser.uid != uid) {
      throw Exception('UID de sesión no coincide con UID de registro');
    }

    try {
      // Force token refresh so security rules receive a fresh auth context.
      await currentUser.getIdToken(true);

      // Create or update the base profile first so rules allow later orbitNumber provisioning.
      final profileSnap = await userRef.get();
      if (!profileSnap.exists) {
        await userRef.set({
          'email': email,
          'fullName': fullName,
          'documentType': documentType,
          'documentNumber': documentNumber,
          'country': country,
          'city': city,
          'accountType': accountType.wireValue,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await userRef.set({
          'fullName': fullName,
          'documentType': documentType,
          'documentNumber': documentNumber,
          'country': country,
          'city': city,
          'accountType': accountType.wireValue,
        }, SetOptions(merge: true));
      }

      try {
        final orbitNumber = await _getOrCreateOrbitNumber(
          firestore: firestore,
          uid: currentUser.uid,
        );

        await userRef.set({
          'orbitNumber': orbitNumber,
        }, SetOptions(merge: true));

        // Espejo público: solo campos no sensibles para búsqueda por Code Orbit.
        await _writePublicProfile(
          firestore: firestore,
          uid: uid,
          fullName: fullName,
          orbitNumber: orbitNumber,
          accountType: accountType,
        );
      } catch (e, st) {
        // Se tolera para no romper registro; se reintentará en siguiente sesión.
        debugPrint('No se pudo asignar OrbitNumber durante registro: $e\n$st');
      }
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception(
            'Firestore denegó permisos al crear users/$uid. Verifica que las reglas desplegadas permitan write cuando request.auth.uid == userId.');
      }
      throw Exception('Error guardando perfil en Firestore: ${e.code}');
    }
  }

  static Future<void> _writePublicProfile({
    required FirebaseFirestore firestore,
    required String uid,
    String? fullName,
    String? orbitNumber,
    AccountType accountType = AccountType.general,
  }) async {
    try {
      await firestore.collection('users_public').doc(uid).set({
        'fullName': fullName,
        'orbitNumber': orbitNumber,
        'accountType': accountType.wireValue,
      }, SetOptions(merge: true));
    } catch (e) {
      // No-critical: no bloquea el flujo de registro/login.
      debugPrint('users_public write failed (non-critical): $e');
    }
  }

  static Future<String> _getOrCreateOrbitNumber({
    required FirebaseFirestore firestore,
    required String uid,
  }) async {
    final userRef = firestore.collection('users').doc(uid);
    final existingUser = await userRef.get();
    final existingNumber =
        (existingUser.data()?['orbitNumber'] as String?)?.trim();
    if (existingNumber != null && existingNumber.isNotEmpty) {
      await _ensureOrbitNumberIndex(
        firestore: firestore,
        uid: uid,
        orbitNumber: existingNumber,
      );
      return existingNumber;
    }

    // Aumentar reintentos a 25 y usar backoff exponencial para zonas remotas
    for (var attempt = 0; attempt < 25; attempt++) {
      try {
        final candidate = _generateOrbitNumber();
        final claimed = await firestore.runTransaction<bool>((tx) async {
          final numberRef = firestore.collection('orbitNumbers').doc(candidate);
          final numberSnap = await tx.get(numberRef);
          if (numberSnap.exists) {
            final existingUid = numberSnap.data()?['uid'] as String?;
            if (existingUid == uid) {
              // Ya nos pertenece, devolver true
              return true;
            }
            return false;
          }

          tx.set(numberRef, {
            'uid': uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
          tx.set(
              userRef,
              {
                'orbitNumber': candidate,
                'orbitNumberAssignedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true));
          return true;
        });

        if (claimed) {
          return candidate;
        }
      } catch (_) {
        // Reintentar con otro candidato en la siguiente iteracion.
      }

      // Backoff exponencial: 100ms, 200ms, 400ms, 800ms,etc. (maximo 5s)
      // Para tolerar latencia alta en zonas remotas
      final delayMs = (100 * (1 << (attempt ~/ 3))).clamp(0, 5000);
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }

    throw Exception('No se pudo generar un numero Orbit unico');
  }

  static Future<void> _ensureOrbitNumberIndex({
    required FirebaseFirestore firestore,
    required String uid,
    required String orbitNumber,
  }) async {
    final numberRef = firestore.collection('orbitNumbers').doc(orbitNumber);
    final snap = await numberRef.get();
    if (snap.exists) {
      final ownerUid = snap.data()?['uid'] as String?;
      if (ownerUid == uid) {
        return;
      }
      throw Exception('El numero Orbit ya pertenece a otro usuario');
    }

    await numberRef.set({
      'uid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: false));
  }

  static String _generateOrbitNumber() {
    final number = 10000000 + _random.nextInt(90000000);
    return number.toString();
  }

  static Future<String?> resolveUserIdFromContactIdentifier(
    String identifier,
  ) async {
    final value = identifier.trim();
    if (value.isEmpty) return null;

    final normalized = value.toUpperCase().startsWith('OR-')
        ? value.substring(3).trim()
        : value;

    final digitsOnly = RegExp(r'^\d{7,12}$').hasMatch(normalized);
    if (!digitsOnly) {
      return normalized;
    }

    final numberDoc = await FirebaseFirestore.instance
        .collection('orbitNumbers')
        .doc(normalized)
        .get();

    if (!numberDoc.exists) {
      return null;
    }

    final uid = numberDoc.data()?['uid'] as String?;
    if (uid == null || uid.trim().isEmpty) {
      return null;
    }
    return uid;
  }

  // ================== LOGIN ==================
  static Future<void> login({
    required String email,
    required String password,
  }) async {
    if (!_canAttemptLogin(email)) {
      throw Exception(
        'Demasiados intentos para este correo. Espera 15 minutos antes de reintentar.',
      );
    }

    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (cred.user == null) {
        throw Exception('Login inválido');
      }

      _clearFailedLoginAttempts(email);

      // Si el perfil de Firestore no existe (ej: fue borrado manualmente),
      // se recrea con los datos básicos del usuario de Auth.
      await ensureCurrentUserProvisioned();

      final isSessionValid = await validateCurrentSession(
        requireUserProfile: true,
        signOutOnInvalid: true,
      );
      if (!isSessionValid) {
        throw Exception(
          'Tu cuenta no está disponible. Inicia sesión nuevamente o regístrate.',
        );
      }

      // Save FCM token after successful login.
      await FCMService.saveCurrentToken();
    } on FirebaseAuthException catch (e) {
      if (_shouldCountAsFailedLogin(e.code)) {
        _recordFailedLoginAttempt(email);
      }
      throw Exception(_firebaseError(e.code, isRegistration: false));
    }
  }

  static bool _canAttemptLogin(
    String email, {
    DateTime? now,
  }) {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      return true;
    }

    final currentTime = now ?? DateTime.now();
    final window = _loginAttemptWindows[normalizedEmail];
    if (window == null) {
      return true;
    }

    if (currentTime.difference(window.startedAt) >=
        _loginAttemptWindowDuration) {
      _loginAttemptWindows.remove(normalizedEmail);
      return true;
    }

    return window.failedAttempts < _maxFailedLoginAttempts;
  }

  static void _recordFailedLoginAttempt(
    String email, {
    DateTime? now,
  }) {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      return;
    }

    final currentTime = now ?? DateTime.now();
    final existingWindow = _loginAttemptWindows[normalizedEmail];
    if (existingWindow == null ||
        currentTime.difference(existingWindow.startedAt) >=
            _loginAttemptWindowDuration) {
      _loginAttemptWindows[normalizedEmail] = _LoginAttemptWindow(
        startedAt: currentTime,
        failedAttempts: 1,
      );
      return;
    }

    _loginAttemptWindows[normalizedEmail] = existingWindow.copyWith(
      failedAttempts: existingWindow.failedAttempts + 1,
    );
  }

  static void _clearFailedLoginAttempts(String email) {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      return;
    }
    _loginAttemptWindows.remove(normalizedEmail);
  }

  static bool _shouldCountAsFailedLogin(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
      case 'user-not-found':
        return true;
      default:
        return false;
    }
  }

  static bool _canAttemptRegistration(
    String email, {
    DateTime? now,
  }) {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      return true;
    }

    final currentTime = now ?? DateTime.now();
    final window = _registrationAttemptWindows[normalizedEmail];
    if (window == null) {
      return true;
    }

    if (currentTime.difference(window.startedAt) >=
        _registrationAttemptWindowDuration) {
      _registrationAttemptWindows.remove(normalizedEmail);
      return true;
    }

    return window.failedAttempts < _maxFailedRegistrationAttempts;
  }

  static void _recordFailedRegistrationAttempt(
    String email, {
    DateTime? now,
  }) {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      return;
    }

    final currentTime = now ?? DateTime.now();
    final existingWindow = _registrationAttemptWindows[normalizedEmail];
    if (existingWindow == null ||
        currentTime.difference(existingWindow.startedAt) >=
            _registrationAttemptWindowDuration) {
      _registrationAttemptWindows[normalizedEmail] = _RegistrationAttemptWindow(
        startedAt: currentTime,
        failedAttempts: 1,
      );
      return;
    }

    _registrationAttemptWindows[normalizedEmail] = existingWindow.copyWith(
      failedAttempts: existingWindow.failedAttempts + 1,
    );
  }

  static void _clearFailedRegistrationAttempts(String email) {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      return;
    }
    _registrationAttemptWindows.remove(normalizedEmail);
  }

  static bool _shouldCountAsFailedRegistration(String code) {
    switch (code) {
      case 'email-already-in-use':
      case 'weak-password':
      case 'invalid-email':
        return true;
      default:
        return false;
    }
  }

  static Future<void> ensureCurrentUserProvisioned() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(currentUser.uid);
    final userSnap = await userRef.get();

    if (!userSnap.exists) {
      await userRef.set({
        'email': currentUser.email ?? '',
        'fullName': currentUser.displayName,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await _getOrCreateOrbitNumber(
      firestore: firestore,
      uid: currentUser.uid,
    );

    await _ensureOrbitNumberAssigned(
      firestore: firestore,
      uid: currentUser.uid,
    );
  }

  // ================== SESSION ==================
  static Future<bool> isLoggedIn() async {
    if (_testCurrentUser != null) {
      return true;
    }
    try {
      return await validateCurrentSession(
        requireUserProfile: true,
        signOutOnInvalid: true,
      );
    } catch (_) {
      // En entornos de prueba sin Firebase inicializado
      return false;
    }
  }

  static Future<bool> validateCurrentSession({
    bool requireUserProfile = true,
    bool signOutOnInvalid = true,
  }) async {
    if (_testCurrentUser != null) {
      return true;
    }

    try {
      var user = _auth.currentUser;
      if (user == null) {
        return false;
      }

      // Fuerza sincronización con Auth para detectar cuentas eliminadas o deshabilitadas.
      await user.reload();
      user = _auth.currentUser;
      if (user == null) {
        if (signOutOnInvalid) {
          await _safeLogout();
        }
        return false;
      }

      if (requireUserProfile) {
        final profile = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (!profile.exists) {
          if (signOutOnInvalid) {
            await _safeLogout();
          }
          return false;
        }

        final profileData = profile.data() ?? <String, dynamic>{};
        final accountType = (profileData['accountType'] as String?)?.trim();
        if (accountType == 'enterprise_admin' ||
            accountType == 'enterprise_employee') {
          final hasAccess = await _hasEnterpriseCommunicationAccess(
            uid: user.uid,
            profileData: profileData,
          );
          if (!hasAccess) {
            if (signOutOnInvalid) {
              await _safeLogout();
            }
            return false;
          }
        }
      }

      return true;
    } on FirebaseAuthException catch (e) {
      if (_invalidSessionAuthCodes.contains(e.code)) {
        if (signOutOnInvalid) {
          await _safeLogout();
        }
        return false;
      }
      rethrow;
    } on FirebaseException catch (e) {
      // Si no se puede leer el perfil por permisos o inexistencia, se invalida sesión local.
      if (e.code == 'permission-denied' || e.code == 'not-found') {
        if (signOutOnInvalid) {
          await _safeLogout();
        }
        return false;
      }
      rethrow;
    }
  }

  static Future<void> _safeLogout() async {
    try {
      await _auth.signOut();
    } catch (_) {}
  }

  static Future<void> ensureCommunicationAccess() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No hay sesión activa');
    }

    final profileSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!profileSnap.exists) {
      throw Exception('Perfil no disponible');
    }

    final profileData = profileSnap.data() ?? <String, dynamic>{};
    final accountType = (profileData['accountType'] as String?)?.trim();
    if (accountType == 'enterprise_admin' ||
        accountType == 'enterprise_employee') {
      final allowed = await _hasEnterpriseCommunicationAccess(
        uid: user.uid,
        profileData: profileData,
      );
      if (!allowed) {
        throw Exception(
          'Tu organización no tiene acceso activo (plan/cupos/miembro).',
        );
      }
    }
  }

  static Future<bool> _hasEnterpriseCommunicationAccess({
    required String uid,
    required Map<String, dynamic> profileData,
  }) async {
    final orgId = (profileData['organizationId'] as String?)?.trim();
    if (orgId == null || orgId.isEmpty) return false;

    final orgSnap = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgId)
        .get();
    if (!orgSnap.exists) return false;

    final orgData = orgSnap.data() ?? <String, dynamic>{};
    final status = (orgData['status'] as String?)?.trim().toLowerCase();
    final isActivePlan = status == 'active' || status == 'trial';
    if (!isActivePlan) return false;

    final seatsPurchased = (orgData['seatsPurchased'] as num?)?.toInt() ?? 0;
    final seatsUsed = (orgData['seatsUsed'] as num?)?.toInt() ?? 0;
    if (seatsPurchased <= 0 || seatsUsed > seatsPurchased) return false;

    final memberSnap = await FirebaseFirestore.instance
        .collection('organizationUsers')
        .doc('${orgId}_$uid')
        .get();
    if (!memberSnap.exists) return false;

    final active = memberSnap.data()?['active'] as bool? ?? false;
    return active;
  }

  static User? getCurrentUser() {
    if (_testCurrentUser != null) {
      return _testCurrentUser;
    }
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  static Future<void> logout() async {
    await _auth.signOut();
  }

  // ================== UTIL ==================
  static String _firebaseError(String code, {bool isRegistration = false}) {
    switch (code) {
      case 'email-already-in-use':
        return 'El correo o contraseña no son válidos';
      case 'invalid-email':
        return 'El correo o contraseña no son válidos';
      case 'weak-password':
        return 'El correo o contraseña no son válidos';
      case 'user-not-found':
        return 'El correo o contraseña no son válidos';
      case 'wrong-password':
        return 'El correo o contraseña no son válidos';
      case 'invalid-credential':
        return 'El correo o contraseña no son válidos';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta de nuevo más tarde';
      case 'network-request-failed':
        return 'Sin conexion a internet';
      default:
        return 'Error de autenticación';
    }
  }
}

class _LoginAttemptWindow {
  const _LoginAttemptWindow({
    required this.startedAt,
    required this.failedAttempts,
  });

  final DateTime startedAt;
  final int failedAttempts;

  _LoginAttemptWindow copyWith({
    DateTime? startedAt,
    int? failedAttempts,
  }) {
    return _LoginAttemptWindow(
      startedAt: startedAt ?? this.startedAt,
      failedAttempts: failedAttempts ?? this.failedAttempts,
    );
  }
}

class _RegistrationAttemptWindow {
  const _RegistrationAttemptWindow({
    required this.startedAt,
    required this.failedAttempts,
  });

  final DateTime startedAt;
  final int failedAttempts;

  _RegistrationAttemptWindow copyWith({
    DateTime? startedAt,
    int? failedAttempts,
  }) {
    return _RegistrationAttemptWindow(
      startedAt: startedAt ?? this.startedAt,
      failedAttempts: failedAttempts ?? this.failedAttempts,
    );
  }
}
