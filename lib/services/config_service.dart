import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Servicio centralizado para obtener configuración desde Firebase Remote Config
/// Reemplaza variables hardcodeadas con valores dinámicos seguros
class ConfigService {
  static final ConfigService _instance = ConfigService._internal();

  factory ConfigService() {
    return _instance;
  }

  ConfigService._internal();

  static final FirebaseRemoteConfig _remoteConfig =
      FirebaseRemoteConfig.instance;
  static bool _initialized = false;

  /// Inicializa Remote Config con defaults y valores en caché
  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: const Duration(
            hours: 1,
          ), // Cachea por 1 hora en producción
        ),
      );

      // Establece valores por defecto en caso de que Remote Config no esté disponible
      await _remoteConfig.setDefaults({
        'openweather_api_key': '', // Se debe configurar en Firebase Console
        'api_base_url': 'https://api.orbit.app',
        'enable_feature_ai': true,
      });

      // Intenta obtener valores más recientes de Firebase
      await _remoteConfig.fetchAndActivate();
      _initialized = true;

      if (kDebugMode) {
        debugPrint('✓ ConfigService inicializado con Remote Config');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠ Error inicializando Remote Config: $e');
      }
    }
  }

  /// Obtiene API Key de OpenWeatherMap desde Remote Config
  /// En caso de error o no estar configurado, retorna string vacío
  static String getOpenWeatherApiKey() {
    try {
      final key = _remoteConfig.getString('openweather_api_key');
      if (key.isEmpty) {
        debugPrint(
          '⚠ AVISO: openweather_api_key no está configurado en Remote Config',
        );
      }
      return key;
    } catch (e) {
      debugPrint('Error obteniendo openweather_api_key: $e');
      return '';
    }
  }

  /// Obtiene URL base de API desde Remote Config
  static String getApiBaseUrl() {
    try {
      return _remoteConfig.getString('api_base_url');
    } catch (e) {
      return 'https://api.orbit.app';
    }
  }

  /// Verifica si una característica está habilitada
  static bool isFeatureEnabled(String featureName) {
    try {
      return _remoteConfig.getBool('enable_feature_$featureName');
    } catch (e) {
      return true; // Por defecto, habilitar características
    }
  }
}
