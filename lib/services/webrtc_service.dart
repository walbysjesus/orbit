import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'turn_stun_config.dart';

/// Servicio WebRTC listo para producción con STUN/TURN públicos
class WebRTCService {
  RTCPeerConnection? _peerConnection;
  bool _disposed = false;
  Timer? _heartbeatTimer;
  bool _lastHeartbeatHealthy = false;
  void Function(bool healthy)? onHeartbeatHealthChanged;

  List<Map<String, dynamic>> _buildIceServers() {
    // ========== PHASE 2: Use centralized TurnStunConfig ==========
    return TurnStunConfig.buildIceServers();
  }

  Future<void> initConnection({bool isCaller = true}) async {
    if (_disposed) return; // lifecycle safety fix
    final config = {
      'iceServers': _buildIceServers(),
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
      'tcpCandidatePolicy': 'disabled',
      'continualGatheringPolicy': 'gather_once',
      'iceCandidatePoolSize': 0,
    };
    _peerConnection = await createPeerConnection(config);
    if (_disposed) {
      // lifecycle safety fix
      await _peerConnection?.close();
      _peerConnection = null;
      return;
    }
    // Puedes agregar listeners para onIceCandidate, onTrack, etc.
  }

  Future<RTCSessionDescription> createOffer({bool iceRestart = false}) async {
    if (_disposed) throw Exception('Service disposed'); // lifecycle safety fix
    if (_peerConnection == null) throw Exception('No peer connection');
    final offer =
        await _peerConnection!.createOffer({'iceRestart': iceRestart});
    if (_disposed) throw Exception('Service disposed'); // lifecycle safety fix
    await _peerConnection!.setLocalDescription(offer);
    return offer;
  }

  void startConnectionHeartbeat({
    Duration interval = const Duration(seconds: 8),
    int unhealthyThreshold = 2,
  }) {
    _heartbeatTimer?.cancel();
    var unhealthyTicks = 0;
    _heartbeatTimer = Timer.periodic(interval, (_) {
      if (_disposed || _peerConnection == null) return;
      final state = _peerConnection!.iceConnectionState;
      final healthy =
          state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
              state == RTCIceConnectionState.RTCIceConnectionStateCompleted;
      if (healthy) {
        unhealthyTicks = 0;
      } else {
        unhealthyTicks++;
      }
      final heartbeatHealthy = healthy || unhealthyTicks < unhealthyThreshold;
      if (heartbeatHealthy != _lastHeartbeatHealthy) {
        _lastHeartbeatHealthy = heartbeatHealthy;
        onHeartbeatHealthChanged?.call(heartbeatHealthy);
      }
    });
  }

  void stopConnectionHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<RTCSessionDescription> createAnswer() async {
    if (_disposed) throw Exception('Service disposed'); // lifecycle safety fix
    if (_peerConnection == null) throw Exception('No peer connection');
    final answer = await _peerConnection!.createAnswer();
    if (_disposed) throw Exception('Service disposed'); // lifecycle safety fix
    await _peerConnection!.setLocalDescription(answer);
    return answer;
  }

  Future<void> setRemoteDescription(RTCSessionDescription desc) async {
    if (_disposed) return; // lifecycle safety fix
    if (_peerConnection == null) throw Exception('No peer connection');
    await _peerConnection!.setRemoteDescription(desc);
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    if (_disposed) return; // lifecycle safety fix
    if (_peerConnection == null) throw Exception('No peer connection');
    await _peerConnection!.addCandidate(candidate);
  }

  void dispose() {
    _disposed = true; // lifecycle safety fix
    stopConnectionHeartbeat();
    _peerConnection?.close();
    _peerConnection = null;
  }

  RTCPeerConnection? get peerConnection => _peerConnection;

  static String optimizeSdpForMobileEfficiency(
    String sdp, {
    required int maxVideoBitrateKbps,
    bool preferH264 = true,
  }) {
    var out = sdp;
    if (preferH264) {
      out = _prioritizeH264Payloads(out);
    }
    out = _applyVideoBitrateCaps(out, maxVideoBitrateKbps);
    return out;
  }

  static String _prioritizeH264Payloads(String sdp) {
    final lines = sdp.split('\r\n');
    final h264Payloads = <String>{};

    for (final line in lines) {
      final match = RegExp(r'^a=rtpmap:(\d+)\s+H264\/').firstMatch(line);
      if (match != null) {
        h264Payloads.add(match.group(1)!);
      }
    }

    if (h264Payloads.isEmpty) return sdp;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!line.startsWith('m=video ')) continue;
      final parts = line.split(' ');
      if (parts.length < 4) continue;

      final header = parts.sublist(0, 3);
      final payloads = parts.sublist(3);
      final prioritized = <String>[];
      final rest = <String>[];
      for (final p in payloads) {
        if (h264Payloads.contains(p)) {
          prioritized.add(p);
        } else {
          rest.add(p);
        }
      }
      if (prioritized.isNotEmpty) {
        lines[i] = [...header, ...prioritized, ...rest].join(' ');
      }
    }

    return lines.join('\r\n');
  }

  static String _applyVideoBitrateCaps(String sdp, int bitrateKbps) {
    final safeBitrate = bitrateKbps.clamp(80, 2500);
    final lines = sdp.split('\r\n');
    final output = <String>[];
    var inVideoSection = false;
    var insertedBitrate = false;

    for (final line in lines) {
      if (line.startsWith('m=')) {
        if (inVideoSection && !insertedBitrate) {
          output.add('b=AS:$safeBitrate');
          output.add('b=TIAS:${safeBitrate * 1000}');
        }
        inVideoSection = line.startsWith('m=video ');
        insertedBitrate = false;
      }

      if (inVideoSection &&
          (line.startsWith('b=AS:') || line.startsWith('b=TIAS:'))) {
        if (!insertedBitrate) {
          output.add('b=AS:$safeBitrate');
          output.add('b=TIAS:${safeBitrate * 1000}');
          insertedBitrate = true;
        }
        continue;
      }

      output.add(line);
    }

    if (inVideoSection && !insertedBitrate) {
      output.add('b=AS:$safeBitrate');
      output.add('b=TIAS:${safeBitrate * 1000}');
    }

    return output.join('\r\n');
  }
}
