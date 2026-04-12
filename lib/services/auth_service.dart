import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class AuthService {
  static FirebaseAuth _auth = FirebaseAuth.instance;
  static final Random _random = Random.secure();

  @visibleForTesting
  static set auth(FirebaseAuth auth) => _auth = auth;

  static User? _testCurrentUser;

  static const Set<String> _invalidSessionAuthCodes = {
    'user-not-found',
    'user-disabled',
    'invalid-user-token',
    'user-token-expired',
  };

  @visibleForTesting
  static set testCurrentUser(User? user) => _testCurrentUser = user;

  // ================== REGISTER ==================
  static Future<void> register({
    required String email,
    required String password,
    String? fullName,
    String? documentType,
    String? documentNumber,
    String? country,
    String? city,
  }) async {
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
    } on FirebaseAuthException catch (e) {
      throw Exception(_firebaseError(e.code));
    }
  }

  static Future<void> _ensureOrbitNumberAssigned({
    required FirebaseFirestore firestore,
    required String uid,
  }) async {
    final userRef = firestore.collection('users').doc(uid);

    for (var attempt = 0; attempt < 5; attempt++) {
      await _getOrCreateOrbitNumber(firestore: firestore, uid: uid);

      final snap = await userRef.get();
      final orbitNumber = (snap.data()?['orbitNumber'] as String?)?.trim();
      if (orbitNumber != null && orbitNumber.isNotEmpty) {
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    throw Exception(
      'No se pudo asignar el numero Orbit. Verifica reglas de Firestore y vuelve a intentar.',
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
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await userRef.set({
          'fullName': fullName,
          'documentType': documentType,
          'documentNumber': documentNumber,
          'country': country,
          'city': city,
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

    for (var attempt = 0; attempt < 15; attempt++) {
      final candidate = _generateOrbitNumber();
      final claimed = await firestore.runTransaction<bool>((tx) async {
        final numberRef = firestore.collection('orbitNumbers').doc(candidate);
        final numberSnap = await tx.get(numberRef);
        if (numberSnap.exists) {
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
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (cred.user == null) {
        throw Exception('Login inválido');
      }

      final isSessionValid = await validateCurrentSession(
        requireUserProfile: true,
        signOutOnInvalid: true,
      );
      if (!isSessionValid) {
        throw Exception(
          'Tu cuenta no está disponible. Inicia sesión nuevamente o regístrate.',
        );
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(_firebaseError(e.code));
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
  static String _firebaseError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Este correo ya está registrado';
      case 'invalid-email':
        return 'Correo inválido';
      case 'weak-password':
        return 'La contraseña es muy débil';
      case 'user-not-found':
        return 'Usuario no existe';
      case 'wrong-password':
        return 'Contraseña incorrecta';
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta de nuevo más tarde';
      case 'network-request-failed':
        return 'Sin conexion a internet';
      default:
        return 'Error de autenticación';
    }
  }
}
