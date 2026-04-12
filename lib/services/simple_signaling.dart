import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Servicio de señalización WebRTC con soporte de rooms y autenticación Firebase.
/// - Si el usuario tiene sesión activa, incluye el token de Firebase en cada mensaje.
/// - roomId identifica la sala de videollamada para enrutar SDP/ICE correctamente.
class SimpleSignaling {
  final String serverUrl;

  /// Sala de videollamada. Se envía con cada mensaje de señalización.
  String? roomId;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  bool _isClosedByUser = false;
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;

  Function(Map<String, dynamic>)? onMessage;
  Function(String)? onError;
  Function(bool)? onConnectionChanged;

  SimpleSignaling(this.serverUrl, {this.roomId});

  // ──────────────────────────────────────────────
  // TOKEN
  // ──────────────────────────────────────────────

  /// Obtiene el token de Firebase del usuario actual, o null si no hay sesión.
  Future<String?> _getAuthToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      return await user?.getIdToken();
    } catch (_) {
      return null;
    }
  }

  // ──────────────────────────────────────────────
  // CONNECT / SEND / CLOSE
  // ──────────────────────────────────────────────

  Future<void> connect() async {
    if (_isConnected) return;
    _isClosedByUser = false;
    _reconnectTimer?.cancel();

    try {
      _channel = WebSocketChannel.connect(Uri.parse(serverUrl));
      _isConnected = true;
      _reconnectAttempt = 0;
      onConnectionChanged?.call(true);

      // Identificarse en la sala al conectar
      final token = await _getAuthToken();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (roomId != null && uid != null) {
        _channel!.sink.add(jsonEncode({
          'type': 'join',
          'roomId': roomId,
          'userId': uid,
          if (token != null) 'token': token,
        }));
      }

      _subscription = _channel!.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String);
            if (msg is Map<String, dynamic>) {
              onMessage?.call(msg);
            }
          } catch (_) {
            onError?.call('Mensaje de señalización inválido');
          }
        },
        onError: (_) {
          _isConnected = false;
          onConnectionChanged?.call(false);
          onError?.call('Error de conexión con servidor de señalización');
          _scheduleReconnect();
        },
        onDone: () {
          _isConnected = false;
          onConnectionChanged?.call(false);
          _scheduleReconnect();
        },
        cancelOnError: false,
      );
    } catch (_) {
      _isConnected = false;
      onConnectionChanged?.call(false);
      _scheduleReconnect();
      rethrow;
    }
  }

  void _scheduleReconnect() {
    if (_isClosedByUser || _isConnected) return;

    final attempt = _reconnectAttempt;
    final delaySeconds = (1 << attempt).clamp(1, 20);
    _reconnectAttempt = (attempt + 1).clamp(0, 6);

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      if (_isClosedByUser || _isConnected) return;
      try {
        await connect();
      } catch (_) {
        _scheduleReconnect();
      }
    });
  }

  Future<void> send(Map<String, dynamic> message) async {
    if (!_isConnected || _channel == null) {
      throw StateError('No hay conexión de señalización activa');
    }

    // Incluir roomId y token en cada mensaje saliente
    final token = await _getAuthToken();
    final enriched = {
      ...message,
      if (roomId != null) 'roomId': roomId,
      if (token != null) 'token': token,
    };

    _channel!.sink.add(jsonEncode(enriched));
  }

  Future<void> close() async {
    _isClosedByUser = true;
    _isConnected = false;
    onConnectionChanged?.call(false);
    _reconnectTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    _subscription = null;
    _channel = null;
  }
}
