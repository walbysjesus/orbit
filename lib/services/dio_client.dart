import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Dio client wrapper with certificate pinning support.
/// 
/// For Android, network_security_config.xml pins are enforced.
/// For iOS and additional runtime checks, implement pinning via interceptors.
class DioClient {
  static Dio create({String? baseUrl}) {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? '',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 15),
    ));

    // Add common interceptors
    dio.interceptors.add(LogInterceptor(
      request: kDebugMode,
      requestBody: kDebugMode,
      responseBody: kDebugMode,
    ));

    return dio;
  }
}
