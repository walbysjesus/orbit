// ===============================
// FIREBASE CONFIG
// ===============================
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

// ===============================
// WEATHER API CONFIG
// ===============================
const String openWeatherMapApiKey =
    String.fromEnvironment('OPENWEATHER_API_KEY', defaultValue: '');

// ===============================
// API CONFIG
// ===============================
const String apiBaseUrl = String.fromEnvironment('API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api');

// ===============================
// REAL-TIME COMMUNICATION CONFIG
// ===============================
const String signalingWsUrl = String.fromEnvironment(
  'SIGNALING_WS_URL',
  defaultValue: 'ws://10.0.2.2:8080',
);

const String turnServerUrl =
    String.fromEnvironment('TURN_URL', defaultValue: '');
const String turnServerUsername =
    String.fromEnvironment('TURN_USERNAME', defaultValue: '');
const String turnServerCredential =
    String.fromEnvironment('TURN_CREDENTIAL', defaultValue: '');

const String chatLocalEncryptionKey = String.fromEnvironment(
  'CHAT_LOCAL_AES_KEY',
  defaultValue: '',
);

String get historyEndpoint => '$apiBaseUrl/history';

Future<void> initializeFirebase() async {
  await Firebase.initializeApp();
}

void validateProductionSecurityConfig() {
  final issues = getRealtimeConfigIssues(forRelease: kReleaseMode);
  if (issues.isEmpty) {
    return;
  }

  // En desarrollo se informa, pero no se bloquea la app.
  if (!kReleaseMode) {
    debugPrint('Config warnings (debug): ${issues.join(' | ')}');
    return;
  }

  throw StateError(issues.join(' | '));
}

List<String> getRealtimeConfigIssues({required bool forRelease}) {
  final issues = <String>[];

  if (forRelease && !signalingWsUrl.startsWith('wss://')) {
    issues.add('En release, SIGNALING_WS_URL debe usar wss://');
  }

  final turnUrl = turnServerUrl.trim().toLowerCase();
  final turnConfigured =
      turnUrl.startsWith('turn:') || turnUrl.startsWith('turns:');
  if (!turnConfigured) {
    issues.add(
        'Configura TURN_URL (turn: o turns:) para llamadas estables en NAT/red móvil');
  }

  if (turnConfigured &&
      (turnServerUsername.trim().isEmpty ||
          turnServerCredential.trim().isEmpty)) {
    issues.add('TURN_URL requiere TURN_USERNAME y TURN_CREDENTIAL');
  }

  if (forRelease && chatLocalEncryptionKey.trim().length < 32) {
    issues.add(
        'En release, CHAT_LOCAL_AES_KEY debe tener al menos 32 caracteres');
  }

  return issues;
}

// ===============================
// SATELLITE NETWORK OPTIMIZATION
// ===============================

/// Configuración optimizada para llamadas por satélite (alta latencia, baja velocidad)
class SatelliteCallConfig {
  // Codecs y bitrate reducidos para satélite
  static const int videoCodecBitrateSatelliteKbps = 256; // vs 750 en normal
  static const int audioCodecBitrateSatelliteKbps = 24; // vs 50 en normal

  // Buffer más grande para compensar jitter/latencia
  static const int jitterBufferMs = 500; // vs 50-100 en normal
  static const int peerConnectionTimeoutS = 30; // vs 10 en normal

  // Reconexión más tolerante
  static const int maxReconnectAttempts = 5;
  static const Duration baseReconnectDelay = Duration(seconds: 2);
}

/// Obtiene configuración optimizada basada en tipo de red
SatelliteCallConfig? getSatelliteConfigIfNeeded(bool isSatellite) {
  return isSatellite ? SatelliteCallConfig() : null;
}
