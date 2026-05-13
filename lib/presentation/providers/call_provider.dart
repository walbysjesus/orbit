import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../services/webrtc_service.dart';

/// Estado de llamada: idle, ringing, in_call, ended
class CallState {
  final String? callId;
  final String? remoteUserId;
  final String status;
  final bool isVideo;

  CallState({
    this.callId,
    this.remoteUserId,
    this.status = 'idle',
    this.isVideo = false,
  });

  CallState copyWith({
    String? callId,
    String? remoteUserId,
    String? status,
    bool? isVideo,
  }) =>
      CallState(
        callId: callId ?? this.callId,
        remoteUserId: remoteUserId ?? this.remoteUserId,
        status: status ?? this.status,
        isVideo: isVideo ?? this.isVideo,
      );
}

class CallNotifier extends StateNotifier<CallState> {
  final WebRTCService _webrtcService = WebRTCService();
  Function(String sdp, String type)? onLocalOffer;
  Function(String sdp, String type)? onLocalAnswer;
  Function(RTCIceCandidate candidate)? onLocalIceCandidate;
  CallNotifier() : super(CallState());

  Future<void> startCall(String remoteUserId, {bool video = false}) async {
    await _webrtcService.initConnection(isCaller: true);
    _webrtcService.peerConnection?.onIceCandidate = (candidate) {
      onLocalIceCandidate?.call(candidate);
    };
    final offer = await _webrtcService.createOffer();
    onLocalOffer?.call(offer.sdp ?? '', offer.type ?? 'offer');
    state = state.copyWith(
      callId: DateTime.now().millisecondsSinceEpoch.toString(),
      remoteUserId: remoteUserId,
      status: 'ringing',
      isVideo: video,
    );
  }

  Future<void> acceptCall(String callId, {required String remoteSdp}) async {
    await _webrtcService.initConnection(isCaller: false);
    _webrtcService.peerConnection?.onIceCandidate = (candidate) {
      onLocalIceCandidate?.call(candidate);
    };
    await _webrtcService
        .setRemoteDescription(RTCSessionDescription(remoteSdp, 'offer'));
    final answer = await _webrtcService.createAnswer();
    onLocalAnswer?.call(answer.sdp ?? '', answer.type ?? 'answer');
    state = state.copyWith(status: 'in_call', callId: callId);
  }

  Future<void> setRemoteAnswer(String sdp) async {
    await _webrtcService
        .setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
  }

  Future<void> addRemoteIceCandidate(Map<String, dynamic> candidate) async {
    final ice = RTCIceCandidate(
      candidate['candidate'] as String,
      candidate['sdpMid'] as String? ?? '',
      candidate['sdpMLineIndex'] as int? ?? 0,
    );
    await _webrtcService.addIceCandidate(ice);
  }

  void endCall() {
    _webrtcService.dispose();
    state = state.copyWith(status: 'ended');
  }

  void reset() {
    _webrtcService.dispose();
    state = CallState();
  }
}

final callProvider = StateNotifierProvider<CallNotifier, CallState>(
  (ref) => CallNotifier(),
);
