import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

/// Servicio de autenticación multi-factor (MFA)
/// Soporta TOTP (Time-based One-Time Password) y códigos de respaldo
class MfaService {
  static const _secureStorage = FlutterSecureStorage();
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ==================== SETUP TOTP ====================

  /// Genera secreto TOTP para el usuario
  /// Retorna: {secret, qrCode}
  static Future<Map<String, String>> generateTotpSecret() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final secret = _generateRandomSecret(32);

    // Guardar temporalmente en almacenamiento seguro (pendiente de confirmación)
    await _secureStorage.write(
      key: 'totp_secret_pending_${user.uid}',
      value: secret,
    );

    // Generar QR Code URL para Google Authenticator, Authy, Microsoft Authenticator
    final qrCode = _generateQrCodeUrl(
      secret: secret,
      email: user.email ?? 'orbit-user',
      issuer: 'Orbit',
    );

    return {
      'secret': secret,
      'qrCode': qrCode,
    };
  }

  /// Confirma la activación de TOTP verificando un código
  static Future<void> confirmTotpSetup({
    required String totpCode,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    // Obtener secret pendiente
    final secret = await _secureStorage.read(
      key: 'totp_secret_pending_${user.uid}',
    );

    if (secret == null) {
      throw Exception('No hay configuración TOTP pendiente');
    }

    // Validar código TOTP
    if (!_verifyTotp(secret, totpCode)) {
      throw Exception('Código TOTP inválido');
    }

    // Guardar secret confirmado de forma segura
    await _secureStorage.write(
      key: 'totp_secret_${user.uid}',
      value: secret,
    );

    // Limpiar pendiente
    await _secureStorage.delete(key: 'totp_secret_pending_${user.uid}');

    // Generar códigos de respaldo (backup codes)
    final backupCodes = _generateBackupCodes(10);
    await _secureStorage.write(
      key: 'backup_codes_${user.uid}',
      value: backupCodes.join('|'),
    );

    // Actualizar Firestore
    await _firestore.collection('users').doc(user.uid).set({
      'mfaEnabled': true,
      'preferredMfaMethod': 'totp',
      'mfaSetupAt': FieldValue.serverTimestamp(),
      'backupCodesCount': backupCodes.length,
    }, SetOptions(merge: true));

    // Registrar evento
    await _logMfaEvent(
      userId: user.uid,
      eventType: 'mfa_enabled',
      method: 'totp',
    );
  }

  /// Verifica código TOTP durante login
  static Future<bool> verifyTotpCode(String code) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final secret = await _secureStorage.read(
      key: 'totp_secret_${user.uid}',
    );

    if (secret == null) {
      throw Exception('MFA no está configurado');
    }

    // Verificar código TOTP (con ventana de 30 segundos)
    if (_verifyTotp(secret, code)) {
      return true;
    }

    // Intentar con código de respaldo
    if (await _verifyBackupCode(user.uid, code)) {
      return true;
    }

    throw Exception('Código TOTP o de respaldo inválido');
  }

  // ==================== CÓDIGOS DE RESPALDO ====================

  /// Obtiene lista de códigos de respaldo (sin revelar códigos)
  static Future<int> getBackupCodesCount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final codes = await _secureStorage.read(
      key: 'backup_codes_${user.uid}',
    );

    if (codes == null) return 0;
    return codes.split('|').length;
  }

  /// Regenera códigos de respaldo
  static Future<List<String>> regenerateBackupCodes() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final backupCodes = _generateBackupCodes(10);
    await _secureStorage.write(
      key: 'backup_codes_${user.uid}',
      value: backupCodes.join('|'),
    );

    await _logMfaEvent(
      userId: user.uid,
      eventType: 'backup_codes_regenerated',
      method: 'totp',
    );

    return backupCodes;
  }

  /// Verifica y consume un código de respaldo
  static Future<bool> _verifyBackupCode(
    String userId,
    String code,
  ) async {
    try {
      final codes = await _secureStorage.read(
        key: 'backup_codes_$userId',
      );

      if (codes == null) return false;

      final codeList = codes.split('|');
      if (codeList.contains(code)) {
        // Consumir el código (remover de la lista)
        codeList.remove(code);
        await _secureStorage.write(
          key: 'backup_codes_$userId',
          value: codeList.join('|'),
        );

        await _logMfaEvent(
          userId: userId,
          eventType: 'backup_code_used',
          method: 'totp',
        );

        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error verificando codigo de respaldo: $e');
      return false;
    }
  }

  // ==================== DESHABILITAR MFA ====================

  /// Desactiva MFA para el usuario
  /// Requiere contraseña actual para seguridad
  static Future<void> disableMfa({
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('Usuario no autenticado');
    }

    try {
      // Reautenticar
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // Eliminar datos de MFA
      await _secureStorage.delete(key: 'totp_secret_${user.uid}');
      await _secureStorage.delete(
        key: 'totp_secret_pending_${user.uid}',
      );
      await _secureStorage.delete(key: 'backup_codes_${user.uid}');

      // Actualizar Firestore
      await _firestore.collection('users').doc(user.uid).set({
        'mfaEnabled': false,
        'preferredMfaMethod': null,
      }, SetOptions(merge: true));

      await _logMfaEvent(
        userId: user.uid,
        eventType: 'mfa_disabled',
        method: 'totp',
      );
    } on FirebaseAuthException catch (e) {
      throw Exception('Contraseña incorrecta: ${e.code}');
    }
  }

  // ==================== HELPERS ====================

  /// Verifica si TOTP está habilitado
  static Future<bool> isMfaEnabled() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final secret = await _secureStorage.read(
      key: 'totp_secret_${user.uid}',
    );

    return secret != null;
  }

  /// Genera secreto aleatorio de 32 caracteres (base32)
  static String _generateRandomSecret(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'; // Base32 alphabet
    final random = List.generate(length, (_) {
      return chars[DateTime.now().microsecond % chars.length];
    });
    return random.join();
  }

  /// Genera 10 códigos de respaldo aleatorios de 8 caracteres
  static List<String> _generateBackupCodes(int count) {
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final codes = <String>[];

    for (int i = 0; i < count; i++) {
      final code = List.generate(8, (_) {
        return chars[DateTime.now().microsecond % chars.length];
      }).join();
      codes.add(code);
    }

    return codes;
  }

  /// Verifica un código TOTP
  /// RFC 4226 compatible
  static bool _verifyTotp(
    String secret,
    String code,
  ) {
    try {
      final now = DateTime.now();

      // Verificar código actual y anteriores/siguientes (ventana de ±30 seg)
      for (int i = -1; i <= 1; i++) {
        final time = (now.millisecondsSinceEpoch ~/ 30000) + i; // 30 segundos
        final expectedCode = _generateTotpCode(secret, time);

        if (expectedCode == code) {
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('Error verificando TOTP: $e');
      return false;
    }
  }

  /// Genera código TOTP para un tiempo específico
  static String _generateTotpCode(String secret, int timeStep) {
    // Decodificar secret base32
    final secretBytes = base32Decode(secret);

    // Crear HMAC-SHA1
    final counter = <int>[
      (timeStep >> 56) & 0xff,
      (timeStep >> 48) & 0xff,
      (timeStep >> 40) & 0xff,
      (timeStep >> 32) & 0xff,
      (timeStep >> 24) & 0xff,
      (timeStep >> 16) & 0xff,
      (timeStep >> 8) & 0xff,
      timeStep & 0xff,
    ];

    final hmac = Hmac(sha1, secretBytes);
    final digest = hmac.convert(counter);
    final digestBytes = digest.bytes;

    // Extraer offset dinámico
    final offset = digestBytes[digestBytes.length - 1] & 0x0f;
    final code = ((digestBytes[offset] & 0x7f) << 24) |
        ((digestBytes[offset + 1] & 0xff) << 16) |
        ((digestBytes[offset + 2] & 0xff) << 8) |
        (digestBytes[offset + 3] & 0xff);

    return (code % 1000000).toString().padLeft(6, '0');
  }

  /// Decodifica base32
  static List<int> base32Decode(String encoded) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final result = <int>[];

    var buffer = 0;
    var bitsInBuffer = 0;

    for (final char in encoded.split('')) {
      final index = alphabet.indexOf(char);
      if (index == -1) continue;

      buffer = (buffer << 5) | index;
      bitsInBuffer += 5;

      if (bitsInBuffer >= 8) {
        bitsInBuffer -= 8;
        result.add((buffer >> bitsInBuffer) & 0xff);
      }
    }

    return result;
  }

  /// Genera URL QR para Google Authenticator
  static String _generateQrCodeUrl({
    required String secret,
    required String email,
    required String issuer,
  }) {
    final label = Uri.encodeComponent('$issuer ($email)');
    return 'otpauth://totp/$label?secret=$secret&issuer=$issuer';
  }

  /// Registra evento MFA en auditoría
  static Future<void> _logMfaEvent({
    required String userId,
    required String eventType,
    required String method,
  }) async {
    try {
      await _firestore.collection('securityLogs').add({
        'userId': userId,
        'eventType': eventType,
        'method': method,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error registrando evento MFA: $e');
    }
  }
}
