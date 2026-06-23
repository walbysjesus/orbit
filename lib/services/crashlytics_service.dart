import 'package:flutter/foundation.dart';

/// Servicio para inicializar y configurar Firebase Crashlytics (MOCK)
/// En desarrollo, registra errores en console
/// En producción, integrarse con firebase_crashlytics
class CrashlyticsService {
  static bool _initialized = false;

  /// Inicializar Crashlytics con manejo global de errores
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // En debug mode, solo log en console
      if (kDebugMode) {
        debugPrint('✅ [Crashlytics] Deshabilitado en modo DEBUG');
        _initialized = true;
        return;
      }

      // En producción, habilitar recolección
      debugPrint('✅ [Crashlytics] Habilitado en modo RELEASE');

      // Configurar manejador global de errores no capturados
      FlutterError.onError = (errorDetails) {
        debugPrint(
            '❌ [Crashlytics] Error registrado: ${errorDetails.exception}');
      };

      _initialized = true;
      debugPrint('✅ [Crashlytics] Inicialización completada');
    } catch (e) {
      debugPrint('❌ [Crashlytics] Error inicializando: $e');
    }
  }

  /// Registrar un error manualmente
  static Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    Iterable<Object>? information,
    bool fatal = false,
  }) async {
    try {
      debugPrint('📋 [Crashlytics] Error registrado: $reason');
    } catch (e) {
      debugPrint('⚠️  [Crashlytics] Error al registrar: $e');
    }
  }

  /// Registrar un evento personalizado (para análisis)
  static Future<void> recordEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      debugPrint('📊 [Crashlytics] Evento: $name');
    } catch (e) {
      debugPrint('⚠️  [Crashlytics] Error registrando evento: $e');
    }
  }

  /// Establecer datos de usuario para contexto en crashes
  static Future<void> setUserInfo({
    required String userId,
    String? email,
    Map<String, dynamic>? customData,
  }) async {
    try {
      debugPrint('✅ [Crashlytics] Datos usuario establecidos: $userId');
    } catch (e) {
      debugPrint('⚠️  [Crashlytics] Error estableciendo datos usuario: $e');
    }
  }

  /// Limpiar datos de usuario (logout)
  static Future<void> clearUserInfo() async {
    try {
      debugPrint('✅ [Crashlytics] Datos usuario limpiados');
    } catch (e) {
      debugPrint('⚠️  [Crashlytics] Error limpiando datos usuario: $e');
    }
  }
}

