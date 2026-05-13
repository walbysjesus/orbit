import 'package:flutter/foundation.dart';

/// TURN/STUN configuration service for WebRTC
/// Handles fallback servers and validates production readiness
class TurnStunConfig {
  // Production TURN servers (must be injected via --dart-define)
  static const String _turnUrlEnv =
      String.fromEnvironment('TURN_URL', defaultValue: '');
  static const String _turnUsernameEnv =
      String.fromEnvironment('TURN_USERNAME', defaultValue: '');
  static const String _turnCredentialEnv =
      String.fromEnvironment('TURN_CREDENTIAL', defaultValue: '');

  // Public STUN servers (backup for direct connectivity)
  static const List<String> _publicStunServers = [
    'stun:stun.l.google.com:19302',
    'stun:stun1.l.google.com:19302',
    'stun:stun2.l.google.com:19302',
    'stun:stun3.l.google.com:19302',
    'stun:stun4.l.google.com:19302',
  ];

  // Fallback TURN servers for development/testing ONLY
  // ⚠️ These are free tier test credentials - rate limited and unreliable
  // Replace with your own TURN server for production
  static const List<Map<String, dynamic>> _fallbackTurnServers = [
    {
      'urls': 'stun:stun.relay.metered.ca:80',
    },
    {
      'urls': 'turn:global.relay.metered.ca:80',
      'username': 'dev_user_testing_only',
      'credential': 'dev_credential_testing_only',
    },
  ];

  /// Check if TURN is configured via environment variables
  static bool isTurnConfigured() {
    final url = _turnUrlEnv.trim();
    final username = _turnUsernameEnv.trim();
    final credential = _turnCredentialEnv.trim();

    return url.isNotEmpty && username.isNotEmpty && credential.isNotEmpty;
  }

  /// Get configured TURN server or null if not set
  static Map<String, dynamic>? getConfiguredTurn() {
    final url = _turnUrlEnv.trim();
    final username = _turnUsernameEnv.trim();
    final credential = _turnCredentialEnv.trim();

    if (url.isEmpty || username.isEmpty || credential.isEmpty) {
      return null;
    }

    return {
      'urls': url,
      'username': username,
      'credential': credential,
    };
  }

  /// Build complete ICE servers list with TURN/STUN priority
  /// Strategy:
  /// 1. Production TURN (if configured via --dart-define)
  /// 2. Public STUN servers (always available)
  /// 3. Fallback TURN/STUN (only in debug mode)
  static List<Map<String, dynamic>> buildIceServers({
    bool includeTestServers = !kReleaseMode,
  }) {
    final iceServers = <Map<String, dynamic>>[];

    // 1️⃣ Add production TURN if configured
    final turn = getConfiguredTurn();
    if (turn != null) {
      iceServers.add(turn);
      debugPrint('✅ [TURN] Production TURN configured: ${turn['urls']}');
    }

    // 2️⃣ Add public STUN servers (always)
    for (final stun in _publicStunServers) {
      iceServers.add({'urls': stun});
    }
    debugPrint(
        '✅ [STUN] Added ${_publicStunServers.length} public STUN servers');

    // 3️⃣ Add fallback TURN/STUN only in debug mode
    if (includeTestServers && !kReleaseMode) {
      debugPrint(
        '⚠️ [TURN] No production TURN configured. Using fallback test servers (rate-limited).',
      );
      iceServers.addAll(_fallbackTurnServers);
    }

    return iceServers;
  }

  /// Validate TURN/STUN configuration for production
  /// Returns list of issues found (empty if all OK)
  static List<String> validateProduction() {
    final issues = <String>[];

    if (!isTurnConfigured()) {
      issues.add(
        '🔴 TURN not configured. Set --dart-define TURN_URL, TURN_USERNAME, TURN_CREDENTIAL',
      );
    }

    return issues;
  }

  /// Block call initiation if TURN not configured in release mode
  /// Returns error message or null if OK
  static String? shouldBlockCallInRelease() {
    if (!kReleaseMode) return null;

    if (!isTurnConfigured()) {
      return '''
🔴 PRODUCTION BLOCKED: TURN server not configured.

Required for satellite networks and double-NAT.

Configuration:
  flutter build apk --release \\
    --dart-define=TURN_URL=turn:your-server.com:3478 \\
    --dart-define=TURN_USERNAME=your-username \\
    --dart-define=TURN_CREDENTIAL=your-password

Without TURN, calls will fail in 60%+ of production networks.
      ''';
    }

    return null;
  }

  /// Get diagnostic info about current TURN/STUN setup
  static String getDiagnosticInfo() {
    final turn = getConfiguredTurn();
    final isProduction = kReleaseMode;

    return '''
=== TURN/STUN Configuration ===
Mode: ${isProduction ? 'RELEASE (PRODUCTION)' : 'DEBUG (DEVELOPMENT)'}
TURN Configured: ${turn != null ? '✅ YES' : '❌ NO'}
${turn != null ? 'TURN URL: ${turn['urls']}' : 'TURN URL: NOT SET (will use public STUN only)'}
STUN Servers: ${_publicStunServers.length} public + ${!isProduction ? _fallbackTurnServers.length : 0} fallback
Production Validation: ${validateProduction().isEmpty ? '✅ PASS' : '❌ FAIL'}
${validateProduction().isNotEmpty ? 'Issues: ${validateProduction().join(', ')}' : ''}
    ''';
  }
}
