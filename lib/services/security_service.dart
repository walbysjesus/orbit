import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';

/// Servicio centralizado de seguridad con cambio de contraseña real en Firebase
class SecurityService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _secureStorage = FlutterSecureStorage();

  // ==================== CAMBIO DE CONTRASEÑA ====================

  /// Cambia la contraseña del usuario en Firebase Auth
  /// Requiere reautenticación si la sesión es antigua
  static Future<void> changePassword({
    required String newPassword,
    required String currentPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('Usuario no autenticado');
    }

    try {
      // Reautenticar con credenciales actuales
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Cambiar contraseña
      await user.updatePassword(newPassword);

      // Registrar en auditoría
      await _logSecurityEvent(
        userId: user.uid,
        eventType: 'password_changed',
        details: {
          'timestamp': DateTime.now().toIso8601String(),
          'success': true,
        },
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_parseFirebaseError(e.code));
    }
  }

  // ==================== VERIFICACIÓN DE EMAIL ====================

  /// Envía email de verificación al usuario
  static Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    if (user.emailVerified) {
      throw Exception('Email ya verificado');
    }

    try {
      await user.sendEmailVerification(
        ActionCodeSettings(
          url: 'https://orbit-app-1.firebaseapp.com/verify?uid=${user.uid}',
          handleCodeInApp: true,
          iOSBundleId: 'com.orbit.app',
          androidPackageName: 'com.orbit.app',
          androidInstallApp: true,
        ),
      );

      await _logSecurityEvent(
        userId: user.uid,
        eventType: 'email_verification_sent',
        details: {
          'email': user.email,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_parseFirebaseError(e.code));
    }
  }

  /// Verifica si el email del usuario ha sido confirmado
  static Future<bool> isEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    // Recargar datos para obtener estado actual
    await user.reload();
    return user.emailVerified;
  }

  // ==================== MANEJO DE SESIONES Y TIMEOUT ====================

  /// Configura timeout de sesión inactiva
  /// Cierra sesión si pasan X minutos sin actividad
  static Timer? _inactivityTimer;

  static void startInactivityTimer({
    Duration timeout = const Duration(minutes: 30),
    required VoidCallback onTimeout,
  }) {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(timeout, () async {
      await logout();
      onTimeout();
    });
  }

  static void resetInactivityTimer({
    Duration timeout = const Duration(minutes: 30),
    required VoidCallback onTimeout,
  }) {
    _inactivityTimer?.cancel();
    startInactivityTimer(timeout: timeout, onTimeout: onTimeout);
  }

  static void cancelInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  /// Cierra sesión y revoca tokens
  static Future<void> logout() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _logSecurityEvent(
          userId: user.uid,
          eventType: 'logout',
          details: {'timestamp': DateTime.now().toIso8601String()},
        );
      }

      // Limpiar almacenamiento seguro
      await _secureStorage.deleteAll();

      // Finalizar sesión en Firebase
      await _auth.signOut();

      cancelInactivityTimer();
    } catch (e) {
      throw Exception('Error al cerrar sesión: $e');
    }
  }

  // ==================== RATE LIMITING ====================

  /// Verifica y registra intentos de login fallidos
  static Future<bool> canAttemptLogin(String email) async {
    try {
      final userDoc = await _firestore.collection('users').doc(email).get();

      if (!userDoc.exists) {
        // Crear registro si no existe
        await _firestore.collection('users').doc(email).set({
          'loginAttempts': 0,
          'lastFailedAttempt': null,
        }, SetOptions(merge: true));
        return true;
      }

      final data = userDoc.data();
      final attempts = (data?['loginAttempts'] as int?) ?? 0;
      final lockedUntil = (data?['lockedUntil'] as Timestamp?)?.toDate();

      // Si está bloqueado, verifica si ya pasó el tiempo
      if (lockedUntil != null && DateTime.now().isBefore(lockedUntil)) {
        final minutesLeft = lockedUntil.difference(DateTime.now()).inMinutes;
        throw Exception(
          'Cuenta bloqueada. Intenta de nuevo en $minutesLeft minuto(s).',
        );
      }

      // Máximo 5 intentos antes de bloquear por 15 minutos
      if (attempts >= 5) {
        await _firestore.collection('users').doc(email).set({
          'lockedUntil': Timestamp.fromDate(
            DateTime.now().add(const Duration(minutes: 15)),
          ),
        }, SetOptions(merge: true));

        throw Exception(
          'Demasiados intentos fallidos. Intenta de nuevo en 15 minutos.',
        );
      }

      return true;
    } catch (e) {
      rethrow;
    }
  }

  /// Registra intento de login fallido
  static Future<void> recordFailedLoginAttempt(String email) async {
    try {
      await _firestore.collection('users').doc(email).set({
        'loginAttempts': FieldValue.increment(1),
        'lastFailedAttempt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _logSecurityEvent(
        userId: email,
        eventType: 'failed_login',
        details: {'timestamp': DateTime.now().toIso8601String()},
      );
    } catch (e) {
      // Log local si falla Firestore
      print('Error registrando intento fallido: $e');
    }
  }

  /// Limpia intentos de login al autenticar exitosamente
  static Future<void> clearFailedLoginAttempts(String email) async {
    try {
      await _firestore.collection('users').doc(email).set({
        'loginAttempts': 0,
        'lastFailedAttempt': null,
        'lockedUntil': null,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error limpiando intentos: $e');
    }
  }

  // ==================== AUDITORÍA Y LOGGING ====================

  /// Registra evento de seguridad en Firestore
  static Future<void> _logSecurityEvent({
    required String userId,
    required String eventType,
    required Map<String, dynamic> details,
  }) async {
    try {
      await _firestore.collection('securityLogs').add({
        'userId': userId,
        'eventType': eventType,
        'timestamp': FieldValue.serverTimestamp(),
        'details': details,
        'ipAddress': null, // TODO: Obtener IP real si es posible
        'userAgent': null,
      });
    } catch (e) {
      print('Error registrando evento de seguridad: $e');
    }
  }

  // ==================== HELPERS ====================

  static String _parseFirebaseError(String code) {
    switch (code.toLowerCase()) {
      case 'wrong-password':
        return 'Contraseña incorrecta';
      case 'invalid-email':
        return 'Email inválido';
      case 'user-not-found':
        return 'Usuario no encontrado';
      case 'user-disabled':
        return 'Usuario deshabilitado';
      case 'weak-password':
        return 'Contraseña muy débil';
      case 'email-already-in-use':
        return 'Email ya registrado';
      case 'operation-not-allowed':
        return 'Operación no permitida';
      case 'requires-recent-login':
        return 'Debes iniciar sesión nuevamente para hacer este cambio';
      default:
        return 'Error de autenticación: $code';
    }
  }
}

typedef VoidCallback = void Function();
