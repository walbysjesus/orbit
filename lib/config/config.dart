// ===============================
// FIREBASE CONFIG
// ===============================
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:orbit/firebase_options.dart';
import 'package:orbit/services/turn_stun_config.dart';

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

const bool orbitIaRemoteEnabled = bool.fromEnvironment(
  'ORBIT_IA_REMOTE_ENABLED',
  defaultValue: false,
);

const String orbitIaRemoteEndpoint = String.fromEnvironment(
  'ORBIT_IA_REMOTE_ENDPOINT',
  defaultValue: '',
);

const bool enforceReleaseSecurityConfig = bool.fromEnvironment(
  'ENFORCE_RELEASE_SECURITY_CONFIG',
  defaultValue: true,
);

// ===============================
// REAL-TIME COMMUNICATION CONFIG
// ===============================
const String signalingWsUrl = String.fromEnvironment(
  'SIGNALING_WS_URL',
  defaultValue: 'ws://10.0.2.2:8080',
);

String get orbitIaRemoteEndpointResolved {
  final custom = orbitIaRemoteEndpoint.trim();
  if (custom.isNotEmpty) {
    return custom;
  }

  final ws = signalingWsUrl.trim();
  if (ws.startsWith('wss://')) {
    return '${ws.replaceFirst('wss://', 'https://')}/api/orbit-ia/chat';
  }
  if (ws.startsWith('ws://')) {
    return '${ws.replaceFirst('ws://', 'http://')}/api/orbit-ia/chat';
  }

  return '$apiBaseUrl/orbit-ia/chat';
}

// ===============================
// TURN/STUN CONFIG (MOVED TO turn_stun_config.dart)
// See lib/services/turn_stun_config.dart for TURN/STUN management
// ===============================
// Use TurnStunConfig.buildIceServers() for WebRTC peer connection
// Use TurnStunConfig.shouldBlockCallInRelease() to validate production readiness

const String chatLocalEncryptionKey = String.fromEnvironment(
  'CHAT_LOCAL_AES_KEY',
  defaultValue: '',
);

const bool allowSecureStorageChatKeyInRelease = bool.fromEnvironment(
  'ALLOW_SECURE_STORAGE_CHAT_KEY',
  defaultValue: true,
);

const String e2eeRoomPayloadVersion = 'e2er2:v1';

String get historyEndpoint => '$apiBaseUrl/history';

bool _firebaseServicesConfigured = false;

Future<void> initializeFirebase() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  await configureFirebaseServices();
}

Future<void> configureFirebaseServices() async {
  if (_firebaseServicesConfigured) {
    return;
  }

  // Offline-first: mantener cache persistente para zonas con conectividad intermitente.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  _firebaseServicesConfigured = true;
}

/// Valida la configuración crítica de seguridad para producción.
/// En release, cualquier error bloquea el inicio de la app.
void validateProductionSecurityConfig() {
  final issues = getRealtimeConfigIssues(forRelease: kReleaseMode);
  if (issues.isEmpty) {
    return;
  }
  // En desarrollo y en release no estricto se informa, pero no se bloquea la app.
  if (!kReleaseMode || !enforceReleaseSecurityConfig) {
    debugPrint('Config warnings (debug): ${issues.join(' | ')}');
    return;
  }
  // En release, cualquier advertencia es fatal.
  throw StateError(issues.join(' | '));
}

List<String> getRealtimeConfigIssues({required bool forRelease}) {
  final issues = <String>[];

  final api = apiBaseUrl.trim().toLowerCase();
  final ws = signalingWsUrl.trim().toLowerCase();

  if (forRelease) {
    if (!api.startsWith('https://')) {
      issues.add('En release, API_BASE_URL debe usar https://');
    }
    if (api.contains('localhost') ||
        api.contains('10.0.2.2') ||
        api.contains('127.0.0.1')) {
      issues.add(
          'En release, API_BASE_URL no puede ser localhost/10.0.2.2/127.0.0.1');
    }
    if (!ws.startsWith('wss://')) {
      issues.add('En release, SIGNALING_WS_URL debe usar wss://');
    }
    if (ws.contains('localhost') ||
        ws.contains('10.0.2.2') ||
        ws.contains('127.0.0.1')) {
      issues.add(
          'En release, SIGNALING_WS_URL no puede ser localhost/10.0.2.2/127.0.0.1');
    }
    if (!allowSecureStorageChatKeyInRelease &&
        chatLocalEncryptionKey.trim().length < 32) {
      issues.add(
          'En release, CHAT_LOCAL_AES_KEY debe tener al menos 32 caracteres cuando ALLOW_SECURE_STORAGE_CHAT_KEY es false');
    }
  }

  // TURN/STUN validation delegated to TurnStunConfig
  final turnIssues = TurnStunConfig.validateProduction();
  issues.addAll(turnIssues);

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
