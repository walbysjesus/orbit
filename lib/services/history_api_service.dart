import 'package:dio/dio.dart';
import 'package:orbit/services/api_client.dart';
import 'dart:convert';
import '../config/config.dart';
import '../services/network_service.dart';
import '../utils/retry_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para obtener historial desde API REST.
/// - Incluye reintentos automáticos y control de errores detallado.
/// - Soporta cache offline para acceso sin conexión.
class HistoryApiService {
  static const String _cacheKey = 'cached_history';

  /// Carga historial desde cache local.
  static Future<List<Map<String, dynamic>>> _loadCachedHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        final List<dynamic> data = jsonDecode(cached);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      // No plugin en testing o preferencia corrupta: devolver lista vacía
      // ignore: avoid_print
      print('Warning: no se pudo leer cache history: $e');
    }
    return [];
  }

  /// Guarda historial en cache local.
  static Future<void> _saveCachedHistory(
      List<Map<String, dynamic>> history) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(history));
    } catch (e) {
      // Ignore en ambientes headless/testing
      // ignore: avoid_print
      print('Warning: no se pudo guardar cache history: $e');
    }
  }

  /// Obtiene historial de mensajes/conversaciones desde el backend.
  /// Reintenta automáticamente hasta 3 veces en caso de error de red.
  /// Si no hay conexión, carga desde cache offline.
  static Future<List<Map<String, dynamic>>> fetchHistory(
      {Dio? client, NetworkService? networkService}) async {
    final url = historyEndpoint; // use string URL for Dio
    final injectedClient = client ?? ApiClient.createAuthenticatedClient();

    bool isConnected = false;
    if (networkService != null) {
      try {
        await networkService.ensureConnected();
        isConnected = true;
      } catch (e) {
        isConnected = false;
      }
    } else {
      // Si no hay networkService, asumir conectado para compatibilidad
      isConnected = true;
    }

    if (!isConnected) {
      // Cargar desde cache offline
      return await _loadCachedHistory();
    }

    try {
      // Timeout de 5 segundos para evitar bloqueos por latencia
      final response = await retry(
        () => injectedClient.get(url).timeout(const Duration(seconds: 5)),
        maxAttempts: 3,
        retryIf: (e) => e is Exception,
      );
      final status = response.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        final data = response.data;
        final List<dynamic> listData = data is String ? jsonDecode(data) : data;
        final history = List<Map<String, dynamic>>.from(listData.cast<Map<String, dynamic>>());
        // Guardar en cache
        await _saveCachedHistory(history);
        return history;
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.statusMessage}');
      }
    } catch (e, st) {
      // Si falla la red, intentar cargar cache
      // ignore: avoid_print
      print('Error en fetchHistory, cargando cache: $e\n$st');
      return await _loadCachedHistory();
    } finally {
      // Dio no requiere cierre explícito. If an external http.Client was
      // provided previously we removed that API; nothing to close here.
    }
  }
}
