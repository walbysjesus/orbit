import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Servicio de señalización WebSocket para llamadas Orbit
class SignalingService {
  final String wsUrl;
  final String roomId;
  final String userId;
  final String token;
  late final WebSocketChannel _channel;
  void Function(String sdp, String type)? onRemoteSdp;
  void Function(Map<String, dynamic> candidate)? onRemoteIceCandidate;
  void Function(String fromUserId)? onPeerJoined;
  void Function(String fromUserId)? onPeerLeft;

  SignalingService({
    required this.wsUrl,
    required this.roomId,
    required this.userId,
    required this.token,
  });

  void connect() {
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    _channel.sink.add(jsonEncode({
      'type': 'join',
      'roomId': roomId,
      'userId': userId,
      'token': token,
    }));
    _channel.stream.listen(_onMessage, onDone: () {}, onError: (e) {});
  }

  void _onMessage(dynamic data) {
    final msg = jsonDecode(data);
    switch (msg['type']) {
      case 'offer':
      case 'answer':
        onRemoteSdp?.call(msg['sdp'], msg['type']);
        break;
      case 'ice-candidate':
        onRemoteIceCandidate?.call(msg['candidate']);
        break;
      case 'peer-joined':
        onPeerJoined?.call(msg['from']);
        break;
      case 'peer-left':
        onPeerLeft?.call(msg['from']);
        break;
    }
  }

  void sendOffer(String sdp) {
    _channel.sink.add(jsonEncode({
      'type': 'offer',
      'sdp': sdp,
      'token': token,
    }));
  }

  void sendAnswer(String sdp) {
    _channel.sink.add(jsonEncode({
      'type': 'answer',
      'sdp': sdp,
      'token': token,
    }));
  }

  void sendIceCandidate(RTCIceCandidate candidate) {
    _channel.sink.add(jsonEncode({
      'type': 'ice-candidate',
      'candidate': {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      },
      'token': token,
    }));
  }

  void close() {
    _channel.sink.close();
  }
}
