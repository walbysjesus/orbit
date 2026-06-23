import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import 'package:orbit/services/api_client.dart';

import '../config/config.dart';

class RemoteNotificationService {
  static Uri _buildNotifyUri() {
    final base = Uri.parse(orbitIaRemoteEndpointResolved);
    return base.replace(path: '/api/notify/user');
  }

  static Future<void> notifyUser({
    required String targetUserId,
    required String type,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    final token = await me.getIdToken();
    final uri = _buildNotifyUri();

    final payload = {
      'targetUserId': targetUserId,
      'type': type,
      'title': title,
      'body': body,
      'data': data ?? <String, String>{},
    };

    try {
      final dio = ApiClient.createAuthenticatedClient();
      final resp = await dio.post(
        uri.toString(),
        data: payload,
        options: Options(headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        }),
      ).timeout(const Duration(seconds: 6));

      final status = resp.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        debugPrint('Notify API fallo ($status): ${resp.data ?? 'sin cuerpo'}');
      }
    } catch (e) {
      debugPrint('Notify API no disponible: $e');
    }
  }
}
