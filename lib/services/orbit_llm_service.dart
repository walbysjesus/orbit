import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/config.dart';
import '../ia_core/orbit_context.dart';

class OrbitLlmResponse {
  final String text;
  final String provider;
  final String model;
  final int latencyMs;

  OrbitLlmResponse({
    required this.text,
    required this.provider,
    required this.model,
    required this.latencyMs,
  });
}

class OrbitLlmService {
  static Future<String?> tryGenerateResponse({
    required String message,
    required OrbitContext context,
  }) async {
    final detailed = await tryGenerateResponseDetailed(
      message: message,
      context: context,
    );
    return detailed?.text;
  }

  static Future<OrbitLlmResponse?> tryGenerateResponseDetailed({
    required String message,
    required OrbitContext context,
  }) async {
    if (!orbitIaRemoteEnabled) {
      return null;
    }

    final endpoint = orbitIaRemoteEndpointResolved;
    final uri = Uri.tryParse(endpoint);
    if (uri == null || uri.scheme.isEmpty) {
      return null;
    }

    final payload = {
      'message': message,
      'conversationId': context.conversationId,
      'userId': context.userId,
      'context': {
        'lastIntent': context.lastIntent,
        'networkQuality': context.networkQuality,
        'weather': context.weatherCondition.name,
        'shortTermMemory': context.shortTermMemory,
        'longTermMemory': context.longTermMemory,
      },
    };

    final authHeader = await _buildAuthHeader();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (authHeader != null) 'Authorization': authHeader,
    };

    // Dos intentos para tolerar intermitencia de red satelital/móvil.
    for (var attempt = 0; attempt < 2; attempt++) {
      final responsePayload = await _requestOnce(
        uri: uri,
        headers: headers,
        payload: payload,
        timeout: Duration(seconds: attempt == 0 ? 6 : 8),
      );
      if (responsePayload != null && responsePayload.text.trim().isNotEmpty) {
        return responsePayload;
      }
    }

    return null;
  }

  static Future<OrbitLlmResponse?> _requestOnce({
    required Uri uri,
    required Map<String, String> headers,
    required Map<String, dynamic> payload,
    required Duration timeout,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();
      final response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(timeout);
      stopwatch.stop();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      if (response.body.trim().isEmpty) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final provider = (decoded['provider'] as String?)?.trim();
      final model = (decoded['model'] as String?)?.trim();

      final candidates = [
        decoded['response'],
        decoded['text'],
        decoded['message'],
        decoded['answer'],
      ];

      for (final value in candidates) {
        if (value is String && value.trim().isNotEmpty) {
          return OrbitLlmResponse(
            text: value.trim(),
            provider:
                provider == null || provider.isEmpty ? 'remote' : provider,
            model: model == null || model.isEmpty ? 'unknown' : model,
            latencyMs: stopwatch.elapsedMilliseconds,
          );
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  static Future<String?> _buildAuthHeader() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return null;
      }

      final token = await user.getIdToken();
      if (token == null || token.trim().isEmpty) {
        return null;
      }

      return 'Bearer $token';
    } catch (_) {
      return null;
    }
  }
}
