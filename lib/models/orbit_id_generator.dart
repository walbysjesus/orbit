
import 'dart:math';
import 'package:uuid/uuid.dart';


/// Utilidad para generar y validar identificadores únicos en Orbit.
class OrbitIdGenerator {
  static final Uuid _uuid = Uuid();

  /// Genera un ID único tipo UUID v4 (ideal para usuarios, mensajes, etc).
  static String generateUuid() {
    return _uuid.v4();
  }

  /// Genera un ID basado en timestamp (útil para logs, eventos, etc).
  static String generateTimestampId() {
    final now = DateTime.now().toUtc();
    return now.microsecondsSinceEpoch.toString();
  }

  /// Genera un ID aleatorio con prefijo ORB-
  static String generateRandomId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    String randomPart() => List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'ORB-${randomPart()}';
  }

  /// Valida si un ID es un UUID v4 válido.
  static bool isValidUuid(String id) {
    try {
      return Uuid.parse(id).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Convierte un ID a base64 (útil para compartir o compactar).
  static String toBase64(String id) {
    return Uri.encodeComponent(id);
  }

  /// Decodifica un ID desde base64.
  static String fromBase64(String encoded) {
    return Uri.decodeComponent(encoded);
  }
}
