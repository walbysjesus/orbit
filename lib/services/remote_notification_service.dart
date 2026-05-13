import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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
      final resp = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 6));

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        debugPrint(
            'Notify API fallo (${resp.statusCode}): ${resp.body.isEmpty ? 'sin cuerpo' : resp.body}');
      }
    } catch (e) {
      debugPrint('Notify API no disponible: $e');
    }
  }
}
