import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';
import 'webrtc_service.dart';
import 'firestore_signaling.dart';
import 'turn_stun_config.dart';

enum CallStatus { pending, ringing, active, ended, rejected, missed }

/// Servicio de llamadas completo con Firebase + WebRTC
/// Soporta: Audio (P2P), Video (P2P), signalización vía Firestore
class CallService {
  static final CallService _instance = CallService._internal();

  factory CallService() {
    return _instance;
  }

  CallService._internal();

  // ─────────────────────────────────────────────────────────
  // DEPENDENCIAS
  // ─────────────────────────────────────────────────────────
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // ─────────────────────────────────────────────────────────
  // ESTADO LOCAL
  // ─────────────────────────────────────────────────────────
  WebRTCService? _webrtcService;
  FirestoreSignaling? _signaling;
  String? _currentCallId;
  String? _currentRemoteUserId;
  String? _currentRoomId;
  CallStatus _callStatus = CallStatus.ended;
  bool _isVideo = false;
  bool _isCaller = false;
  DateTime? _callStartTime;

  // Callbacks
  Function(CallStatus)? onCallStatusChanged;
  Function(String errorMsg)? onError;
  Function()? onRemoteStreamAdded;
  Function()? onRemoteStreamRemoved;

  // ─────────────────────────────────────────────────────────
  // GETTERS
  // ─────────────────────────────────────────────────────────
  String? get currentCallId => _currentCallId;
  String? get currentRemoteUserId => _currentRemoteUserId;
  String? get currentRoomId => _currentRoomId;
  CallStatus get callStatus => _callStatus;
  bool get isVideo => _isVideo;
  bool get isCaller => _isCaller;
  DateTime? get callStartTime => _callStartTime;
  WebRTCService? get webrtcService => _webrtcService;
  MediaStream? get localStream => _webrtcService?.localStream;
  RTCPeerConnection? get peerConnection => _webrtcService?.peerConnection;

  // ─────────────────────────────────────────────────────────
  // INICIAR LLAMADA (Caller)
  // ─────────────────────────────────────────────────────────
  /// Inicia una nueva llamada hacia un usuario remoto
  /// Retorna el roomId de la llamada
  Future<String> initiateCall({
    required String remoteUserId,
    bool isVideo = false,
  }) async {
    try {
      // ✅ Validar TURN en release mode
      final turnError = TurnStunConfig.shouldBlockCallInRelease();
      if (turnError != null) {
        throw Exception(turnError);
      }

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user');
      }

      if (_callStatus != CallStatus.ended) {
        throw Exception('Una llamada ya está en progreso');
      }

      // Generar IDs únicos
      final callId = const Uuid().v4();
      final roomId = '${currentUser.uid}_${remoteUserId}_${DateTime.now().millisecondsSinceEpoch}';

      _currentCallId = callId;
      _currentRemoteUserId = remoteUserId;
      _currentRoomId = roomId;
      _isVideo = isVideo;
      _isCaller = true;

      debugPrint('📞 Iniciando llamada: callId=$callId, roomId=$roomId, video=$isVideo');

      // 1. Crear documento de llamada en Firestore
      await _createCallDocument(
        callId: callId,
        roomId: roomId,
        remoteUserId: remoteUserId,
        isVideo: isVideo,
        currentUser: currentUser,
      );

      // 2. Inicializar WebRTC
      _webrtcService = WebRTCService();
      await _webrtcService!.initConnection(isCaller: true);
      _setupWebRTCListeners();

      // 3. Inicializar signalización Firestore
      _signaling = FirestoreSignaling(roomId: roomId, isCaller: true);
      _setupSignalingListeners();
      await _signaling!.connect();

      // 4. Crear y enviar offer
      final offer = await _webrtcService!.createOffer();
      await _signaling!.send({'type': 'offer', 'sdp': offer.sdp});

      // 5. Enviar notificación FCM al receptor
      await _sendIncomingCallNotification(
        receiverId: remoteUserId,
        callId: callId,
        roomId: roomId,
        callerName: currentUser.displayName ?? 'Usuario',
        callerPhoto: currentUser.photoURL,
        isVideo: isVideo,
      );

      // 6. Actualizar estado
      _callStatus = CallStatus.ringing;
      onCallStatusChanged?.call(_callStatus);
      _startCallTimeout();

      return roomId;
    } catch (e) {
      debugPrint('❌ Error initiating call: $e');
      _callStatus = CallStatus.ended;
      onError?.call('Error al iniciar llamada: $e');
      await cleanup();
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────
  // ACEPTAR LLAMADA (Receiver)
  // ─────────────────────────────────────────────────────────
  /// Acepta una llamada entrante
  Future<void> acceptCall({
    required String callId,
    required String roomId,
    required String callerId,
    bool isVideo = false,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user');
      }

      _currentCallId = callId;
      _currentRoomId = roomId;
      _currentRemoteUserId = callerId;
      _isVideo = isVideo;
      _isCaller = false;

      debugPrint('☎️ Aceptando llamada: callId=$callId, roomId=$roomId, video=$isVideo');

      // 1. Actualizar estado en Firestore
      await _firestore.collection('calls').doc(callId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'acceptedBy': currentUser.uid,
      });

      // 2. Inicializar WebRTC
      _webrtcService = WebRTCService();
      await _webrtcService!.initConnection(isCaller: false);
      _setupWebRTCListeners();

      // 3. Inicializar signalización
      _signaling = FirestoreSignaling(roomId: roomId, isCaller: false);
      _setupSignalingListeners();
      await _signaling!.connect();

      // 4. Actualizar estado local
      _callStatus = CallStatus.active;
      _callStartTime = DateTime.now();
      onCallStatusChanged?.call(_callStatus);
      _startConnectionHeartbeat();

      debugPrint('✅ Llamada aceptada, esperando offer...');
    } catch (e) {
      debugPrint('❌ Error accepting call: $e');
      _callStatus = CallStatus.ended;
      onError?.call('Error al aceptar llamada: $e');
      await cleanup();
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────
  // RECHAZAR LLAMADA
  // ─────────────────────────────────────────────────────────
  Future<void> rejectCall({required String callId}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      await _firestore.collection('calls').doc(callId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': currentUser.uid,
      });

      _callStatus = CallStatus.rejected;
      onCallStatusChanged?.call(_callStatus);
      debugPrint('❌ Llamada rechazada');
    } catch (e) {
      debugPrint('Error rejecting call: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // TERMINAR LLAMADA
  // ─────────────────────────────────────────────────────────
  Future<void> endCall() async {
    try {
      if (_currentCallId == null) return;

      final currentUser = _auth.currentUser;
      final callDuration = _callStartTime != null
          ? DateTime.now().difference(_callStartTime!).inSeconds
          : 0;

      // Actualizar Firestore
      await _firestore.collection('calls').doc(_currentCallId).update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
        'endedBy': currentUser?.uid,
        'duration': callDuration,
      });

      debugPrint('📞 Llamada finalizada. Duración: ${callDuration}s');

      _callStatus = CallStatus.ended;
      onCallStatusChanged?.call(_callStatus);

      await cleanup();
    } catch (e) {
      debugPrint('Error ending call: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // CONTROLES DE AUDIO/VIDEO
  // ─────────────────────────────────────────────────────────
  Future<void> toggleAudio(bool enabled) async {
    if (_webrtcService?.localStream == null) return;
    final audioTracks = _webrtcService!.localStream!.getAudioTracks();
    for (final track in audioTracks) {
      track.enabled = enabled;
    }
    debugPrint('🔊 Audio ${enabled ? 'on' : 'off'}');
  }

  Future<void> toggleVideo(bool enabled) async {
    if (_webrtcService?.localStream == null) return;
    final videoTracks = _webrtcService!.localStream!.getVideoTracks();
    for (final track in videoTracks) {
      track.enabled = enabled;
    }
    debugPrint('📹 Video ${enabled ? 'on' : 'off'}');
  }

  Future<void> switchCamera() async {
    if (_webrtcService?.localStream == null) return;
    final videoTracks = _webrtcService!.localStream!.getVideoTracks();
    for (final track in videoTracks) {
      await Helper.switchCamera(track);
    }
    debugPrint('📹 Cámara cambiada');
  }

  // ─────────────────────────────────────────────────────────
  // LISTENERS PRIVADOS
  // ─────────────────────────────────────────────────────────

  void _setupWebRTCListeners() {
    if (_webrtcService?.peerConnection == null) return;

    _webrtcService!.peerConnection!.onTrack = (event) {
      debugPrint('🎥 Remote track added: ${event.track.kind}');
      onRemoteStreamAdded?.call();
    };

    _webrtcService!.peerConnection!.onIceCandidate = (candidate) {
      if (candidate.candidate?.isNotEmpty == true) {
        _signaling?.send({
          'type': 'candidate',
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMLineIndex': candidate.sdpMLineIndex,
            'sdpMid': candidate.sdpMid,
          },
        });
      }
    };

    _webrtcService!.peerConnection!.onConnectionState = (state) {
      debugPrint('🔗 Connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _callStatus = CallStatus.active;
        if (_callStartTime == null) {
          _callStartTime = DateTime.now();
        }
        onCallStatusChanged?.call(_callStatus);
        _startConnectionHeartbeat();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        debugPrint('❌ Connection failed/closed');
        endCall();
      }
    };
  }

  void _setupSignalingListeners() {
    if (_signaling == null) return;

    _signaling!.onMessage = (message) async {
      final type = message['type'] as String?;
      debugPrint('📨 Signaling message: $type');

      try {
        switch (type) {
          case 'offer':
            final sdp = message['sdp'] as String?;
            if (sdp != null && !_isCaller) {
              final offer = RTCSessionDescription(sdp, 'offer');
              await _webrtcService!.setRemoteDescription(offer);
              final answer = await _webrtcService!.createAnswer();
              await _signaling!.send({'type': 'answer', 'sdp': answer.sdp});
            }
            break;

          case 'answer':
            final sdp = message['sdp'] as String?;
            if (sdp != null && _isCaller) {
              final answer = RTCSessionDescription(sdp, 'answer');
              await _webrtcService!.setRemoteDescription(answer);
            }
            break;

          case 'candidate':
            final candidateData = message['candidate'] as Map<String, dynamic>?;
            if (candidateData != null) {
              final candidate = RTCIceCandidate(
                candidateData['candidate'] as String?,
                candidateData['sdpMid'] as String?,
                candidateData['sdpMLineIndex'] as int?,
              );
              await _webrtcService!.addIceCandidate(candidate);
            }
            break;

          case 'peer-joined':
            debugPrint('👤 Peer joined');
            _callStatus = CallStatus.active;
            if (_callStartTime == null) {
              _callStartTime = DateTime.now();
            }
            onCallStatusChanged?.call(_callStatus);
            break;

          case 'restartIce':
            debugPrint('🔄 ICE restart requested');
            _webrtcService?.startConnectionHeartbeat();
            break;
        }
      } catch (e) {
        debugPrint('Error processing signaling message: $e');
      }
    };

    _signaling!.onError = (error) {
      debugPrint('⚠️ Signaling error: $error');
      onError?.call(error);
    };

    _signaling!.onConnectionChanged = (connected) {
      debugPrint('🔌 Signaling connection: ${connected ? 'connected' : 'disconnected'}');
    };
  }

  // ─────────────────────────────────────────────────────────
  // UTILITARIOS PRIVADOS
  // ─────────────────────────────────────────────────────────

  Future<void> _createCallDocument({
    required String callId,
    required String roomId,
    required String remoteUserId,
    required bool isVideo,
    required User currentUser,
  }) async {
    await _firestore.collection('calls').doc(callId).set({
      'callId': callId,
      'roomId': roomId,
      'callerId': currentUser.uid,
      'callerName': currentUser.displayName ?? 'Usuario',
      'callerPhoto': currentUser.photoURL,
      'receiverId': remoteUserId,
      'isVideo': isVideo,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'acceptedAt': null,
      'endedAt': null,
      'duration': 0,
    });
  }

  void _startCallTimeout({Duration timeout = const Duration(minutes: 1)}) {
    Future.delayed(timeout, () {
      if (_callStatus == CallStatus.ringing) {
        debugPrint('⏰ Llamada expirada (sin respuesta)');
        _callStatus = CallStatus.missed;
        onCallStatusChanged?.call(_callStatus);
        endCall();
      }
    });
  }

  void _startConnectionHeartbeat() {
    _webrtcService?.startConnectionHeartbeat(
      interval: const Duration(seconds: 5),
      unhealthyThreshold: 3,
    );
  }

  Future<void> _sendIncomingCallNotification({
    required String receiverId,
    required String callId,
    required String roomId,
    required String callerName,
    required String? callerPhoto,
    required bool isVideo,
  }) async {
    try {
      // Obtener FCM token del receptor
      final receiverDoc =
          await _firestore.collection('users').doc(receiverId).get();
      final fcmToken = receiverDoc.data()?['fcmToken'] as String?;

      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('⚠️  No FCM token para usuario $receiverId');
        return;
      }

      debugPrint(
          '📲 Enviando notificación FCM: callId=$callId, receptor=$receiverId, video=$isVideo');

      // Registrar en Firestore que se envió
      await _firestore
          .collection('calls')
          .doc(callId)
          .update({'fcmSent': true, 'fcmSentAt': FieldValue.serverTimestamp()});

      debugPrint('✅ Notificación registrada en Firestore');
    } catch (e) {
      debugPrint('❌ Error enviando notificación FCM: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  // LIMPIEZA
  // ─────────────────────────────────────────────────────────
  Future<void> cleanup() async {
    try {
      _webrtcService?.stopConnectionHeartbeat();
      await _webrtcService?.closeConnection();
      await _signaling?.close();

      _webrtcService = null;
      _signaling = null;
      _currentCallId = null;
      _currentRemoteUserId = null;
      _currentRoomId = null;
      _callStartTime = null;

      debugPrint('🧹 CallService cleanup completed');
    } catch (e) {
      debugPrint('Error during cleanup: $e');
    }
  }

  Future<void> dispose() async {
    await cleanup();
  }
}
