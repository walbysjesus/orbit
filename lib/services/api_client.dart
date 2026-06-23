import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'config_service.dart';
import 'dio_client.dart';

/// Provee instancias de `Dio` configuradas para llamadas a la API del backend.
class ApiClient {
  /// Crea un cliente Dio con `baseUrl` desde Remote Config y un interceptor
  /// que añade el `Authorization` Bearer token si el usuario está logueado.
  static Dio createAuthenticatedClient() {
    final baseUrl = ConfigService.getApiBaseUrl();
    final dio = DioClient.create(baseUrl: baseUrl);

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            final token = await user.getIdToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
        } catch (_) {
          // If token retrieval fails, continue without Authorization header.
        }
        return handler.next(options);
      },
    ));

    return dio;
  }
}

