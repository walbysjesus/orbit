import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../config/config.dart';
import '../../services/auth_service.dart';
import '../../services/call_session_service.dart';
import '../../services/network_service.dart';
import '../../services/firestore_signaling.dart';
import '../../utils/camera_icon_button.dart';

// Variables globales eliminadas, deben estar dentro del State

class VideoCallScreen extends StatefulWidget {
  /// ID único de la sala WebRTC. Si no se provee, la pantalla genera uno temporal.
  final String? roomId;

  /// UID del usuario remoto (para mostrar en UI y enrutar sala).
  final String? remoteUserId;

  /// Si es true, inicia una llamada de voz (sin video local/remoto).
  final bool audioOnly;

  /// Fuerza rol de iniciador para evitar oferta simultánea.
  final bool? isCaller;

  /// ID de sesión en Firestore para seguimiento de estado (ringing/accepted/ended).
  final String? callSessionId;

  const VideoCallScreen({
    super.key,
    this.roomId,
    this.remoteUserId,
    this.audioOnly = false,
    this.isCaller,
    this.callSessionId,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late final FirestoreSignaling _signaling;
  RTCPeerConnection? _peerConnection;
  bool _offerSent = false;

  late String _roomId;
  String? _localUserId;
  bool _isCaller = false;
  String? _callSessionId;
  bool _remotePeerJoined = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _callSub;
  Timer? _networkTimer;
  String _networkLabel = 'Analizando señal...';
  Color _networkColor = const Color(0xFF8FA9C2);
  bool _isSatelliteNetwork = false;
  int? _latencyMs;
  bool _controlsExpanded = false;

  late Stopwatch _stopwatch;
  late final Ticker _ticker;
  String _callDuration = '00:00';

  // flutter_webrtc
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  MediaStream? _localStream;

  @override
  void initState() {
    super.initState();
    _localUserId = AuthService.getCurrentUser()?.uid;
    _roomId = _resolveRoomId();
    _isCaller = widget.isCaller ?? _resolveCallerRole();
    _callSessionId = widget.callSessionId;
    _signaling = FirestoreSignaling(roomId: _roomId, isCaller: _isCaller);
    _stopwatch = Stopwatch()..start();
    _ticker = Ticker((_) {
      if (mounted) {
        setState(() {
          final seconds = _stopwatch.elapsed.inSeconds;
          final min = (seconds ~/ 60).toString().padLeft(2, '0');
          final sec = (seconds % 60).toString().padLeft(2, '0');
          _callDuration = '$min:$sec';
        });
      }
    });
    _ticker.start();
    _showRealtimeConfigWarnings();
    _initCall();
    _initCallSession();
    unawaited(_refreshNetworkStatus());
    _networkTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(_refreshNetworkStatus()),
    );
  }

  void _showRealtimeConfigWarnings() {
    final issues = getRealtimeConfigIssues(forRelease: false);
    if (issues.isEmpty) return;
    _showBanner(
      'Configuración recomendada pendiente: ${issues.join(' · ')}',
      Colors.orangeAccent,
      persistent: true,
    );
  }

  Future<void> _refreshNetworkStatus() async {
    final service = NetworkService();
    final quality = await service.getNetworkQuality();
    final latency = await service.measureLatencyMs();
    final isSatellite = await service.isSatelliteConnected();

    String label;
    Color color;
    switch (quality) {
      case NetworkQuality.none:
        label = 'Sin señal';
        color = const Color(0xFFE16B6B);
        break;
      case NetworkQuality.low:
        label = 'Inestable';
        color = const Color(0xFFFFB46A);
        break;
      case NetworkQuality.medium:
        label = 'Señal media';
        color = const Color(0xFFECCB6A);
        break;
      case NetworkQuality.high:
        label = 'Señal alta';
        color = const Color(0xFF63D9B3);
        break;
      case NetworkQuality.unknown:
        label = 'Señal desconocida';
        color = const Color(0xFF8FA9C2);
        break;
    }

    // Si es satélite, agregar indicador
    if (isSatellite) {
      label = '$label · 🛰️ Satélite';
    }

    if (!mounted) return;
    setState(() {
      _networkLabel = latency == null ? label : '$label · ${latency} ms';
      _networkColor = color;
      _latencyMs = latency;
      _isSatelliteNetwork = isSatellite;
    });
  }

  String _buildAutoRoomId() {
    final remote = widget.remoteUserId?.trim();
    final me = _localUserId?.trim();
    if (remote != null && remote.isNotEmpty && me != null && me.isNotEmpty) {
      final pair = [me, remote]..sort();
      return 'call_${pair[0]}_${pair[1]}';
    }
    return 'room_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _resolveRoomId() {
    if (widget.roomId != null && widget.roomId!.trim().isNotEmpty) {
      return widget.roomId!.trim();
    }

    final remote = widget.remoteUserId?.trim();
    final me = _localUserId?.trim();
    if (remote != null && remote.isNotEmpty && me != null && me.isNotEmpty) {
      final pair = [me, remote]..sort();
      return 'call_${pair[0]}_${pair[1]}';
    }

    return _buildAutoRoomId();
  }

  bool _resolveCallerRole() {
    final remote = widget.remoteUserId?.trim();
    final me = _localUserId?.trim();
    if (remote == null || remote.isEmpty || me == null || me.isEmpty) {
      return true;
    }
    return me.compareTo(remote) <= 0;
  }

  @override
  void dispose() {
    unawaited(_endSessionIfNeeded());
    _callSub?.cancel();
    _networkTimer?.cancel();
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        track.stop();
      }
      _localStream!.dispose();
      _localStream = null;
    }
    _peerConnection?.close();
    _peerConnection?.dispose();
    _signaling.close();
    _ticker.dispose();
    _stopwatch.stop();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  Future<void> _initCallSession() async {
    if (_callSessionId != null && _callSessionId!.isNotEmpty) {
      _listenCallSession(_callSessionId!);
      return;
    }

    if (!_isCaller) return;
    final remote = widget.remoteUserId?.trim();
    if (remote == null || remote.isEmpty) return;

    try {
      final createdId = await CallSessionService.createOutgoingSession(
        calleeId: remote,
      );
      if (!mounted) return;
      setState(() => _callSessionId = createdId);
      _listenCallSession(createdId);
    } catch (_) {
      if (!mounted) return;
      _showBanner('No se pudo crear sesión de llamada', Colors.orangeAccent);
    }
  }

  void _listenCallSession(String callId) {
    _callSub?.cancel();
    _callSub = CallSessionService.sessionStream(callId).listen((snap) {
      if (!mounted || !snap.exists) return;
      final data = snap.data();
      final status = (data?['status'] as String?)?.trim();
      if (status == null || status.isEmpty) return;

      if (status == 'accepted') {
        _remotePeerJoined = true;
        if (_isCaller && _localStream != null) {
          unawaited(_createAndSendOffer());
        }
      } else if (status == 'rejected') {
        _showBanner('La llamada fue rechazada', Colors.orangeAccent);
        Navigator.of(context).pop();
      } else if (status == 'ended') {
        _showBanner('La llamada finalizó', Colors.blueGrey);
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _endSessionIfNeeded() async {
    final callId = _callSessionId;
    if (callId == null || callId.isEmpty) return;
    try {
      await CallSessionService.endSession(callId);
    } catch (_) {
      // Ignorar error al cerrar pantalla.
    }
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _initCall() async {
    try {
      if ((widget.remoteUserId ?? '').trim().isEmpty) {
        _showBanner(
            'Falta UID remoto para iniciar la llamada', Colors.redAccent,
            persistent: true);
        return;
      }

      // Mostrar advertencia si está en satélite
      if (_isSatelliteNetwork) {
        _showBanner(
          '🛰️ Conectado vía satélite: Alta latencia esperada (~500ms+)',
          Colors.amber,
          persistent: false,
        );
      }

      await _initRenderers();
      _signaling.onMessage = _handleSignalingMessage;
      _signaling.onError = (error) {
        if (!mounted) return;
        _showBanner(error, Colors.redAccent);
      };
      // Iniciar stream local ANTES de conectar señalización
      // para que el PeerConnection tenga tracks listos antes de procesar SDP.
      await _startLocalStream();
      await _signaling.connect();
    } catch (_) {
      if (!mounted) return;
      _showBanner('No se pudo iniciar la videollamada', Colors.redAccent,
          persistent: true, onRetry: _initCall);
    }
  }

  Future<void> _startLocalStream() async {
    final mediaConstraints = {
      'audio': true,
      'video': widget.audioOnly
          ? false
          : {
              'facingMode': 'user',
              'width': 640,
              'height': 480,
            },
    };
    try {
      _localStream =
          await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _localRenderer.srcObject = _localStream;
      await _createPeerConnection();
      for (final track in _localStream!.getTracks()) {
        await _peerConnection?.addTrack(track, _localStream!);
      }

      // Solo el iniciador envía oferta y la reintenta cuando el otro peer entra.
      if (_isCaller && _remotePeerJoined) {
        await _createAndSendOffer();
      }
    } catch (e) {
      _showBanner('Error al iniciar cámara/micrófono', Colors.redAccent,
          persistent: true, onRetry: _startLocalStream);
    }
  }

  Future<void> _createPeerConnection() async {
    final iceServers = <Map<String, dynamic>>[
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ];

    if (turnServerUrl.trim().isNotEmpty) {
      iceServers.add({
        'urls': turnServerUrl,
        if (turnServerUsername.trim().isNotEmpty)
          'username': turnServerUsername,
        if (turnServerCredential.trim().isNotEmpty)
          'credential': turnServerCredential,
      });
    }

    final config = {
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    };
    _peerConnection = await createPeerConnection(config);
    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        setState(() {
          _remoteRenderer.srcObject = event.streams[0];
        });
      }
    };
    _peerConnection?.onIceCandidate = (candidate) {
      _signaling.send({
        'type': 'candidate',
        'candidate': candidate.toMap(),
      }).catchError((_) {});
    };
  }

  Future<void> _createAndSendOffer() async {
    if (!_isCaller || _offerSent) return;
    _offerSent = true;
    if (_peerConnection == null) await _createPeerConnection();
    final offer = await _peerConnection?.createOffer();
    if (offer == null) return;
    await _peerConnection?.setLocalDescription(offer);
    await _signaling.send({
      'type': 'offer',
      'sdp': offer.sdp,
      if (widget.remoteUserId != null) 'to': widget.remoteUserId,
      if (_localUserId != null) 'from': _localUserId,
    });
  }

  void _handleSignalingMessage(Map<String, dynamic> msg) async {
    switch (msg['type']) {
      case 'joined':
      case 'peer-joined':
        _remotePeerJoined = true;
        if (_isCaller && _localStream != null) {
          await _createAndSendOffer();
        }
        break;
      case 'offer':
        if (_peerConnection == null) await _createPeerConnection();
        await _peerConnection
            ?.setRemoteDescription(RTCSessionDescription(msg['sdp'], 'offer'));
        final answer = await _peerConnection?.createAnswer();
        if (answer != null) {
          await _peerConnection?.setLocalDescription(answer);
          await _signaling.send({
            'type': 'answer',
            'sdp': answer.sdp,
            if (widget.remoteUserId != null) 'to': widget.remoteUserId,
            if (_localUserId != null) 'from': _localUserId,
          });
        }
        break;
      case 'answer':
        await _peerConnection
            ?.setRemoteDescription(RTCSessionDescription(msg['sdp'], 'answer'));
        break;
      case 'candidate':
        final cand = msg['candidate'];
        await _peerConnection?.addCandidate(RTCIceCandidate(
            cand['candidate'], cand['sdpMid'], cand['sdpMLineIndex']));
        break;
    }
  }

  void _toggleMic() {
    if (_localStream != null) {
      for (var track in _localStream!.getAudioTracks()) {
        track.enabled = micOn;
      }
    }
  }

  void _toggleCamera() {
    if (widget.audioOnly) return;
    if (_localStream != null) {
      for (var track in _localStream!.getVideoTracks()) {
        track.enabled = cameraOn;
      }
    }
  }

  void _toggleSpeaker() {
    // flutter_webrtc maneja el altavoz en dispositivos móviles con setSpeakerphoneOn
    Helper.setSpeakerphoneOn(speakerOn);
  }

  MaterialBanner? _activeBanner;

  void _showBanner(String message, Color color,
      {bool persistent = false, VoidCallback? onRetry}) {
    setState(() {
      _activeBanner = MaterialBanner(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        actions: [
          if (onRetry != null)
            TextButton(
              child: const Text('Reintentar',
                  style: TextStyle(color: Colors.white)),
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _activeBanner = null;
                });
                onRetry();
              },
            ),
          TextButton(
            child: const Text('Cerrar', style: TextStyle(color: Colors.white)),
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() {
                _activeBanner = null;
              });
            },
          ),
        ],
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        elevation: 2,
      );
    });
    if (!persistent) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _activeBanner = null;
          });
        }
      });
    }
  }

  bool micOn = true;
  bool speakerOn = false;
  bool cameraOn = true;

  @override
  Widget build(BuildContext context) {
    final hasRemoteVideo = !widget.audioOnly;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_activeBanner != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _activeBanner!,
            ),
          Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasRemoteVideo)
                    SizedBox(
                      width: double.infinity,
                      height: MediaQuery.of(context).size.height * 0.58,
                      child: RTCVideoView(_remoteRenderer,
                          objectFit: RTCVideoViewObjectFit
                              .RTCVideoViewObjectFitContain),
                    ),
                  if (!hasRemoteVideo)
                    const Icon(Icons.call, color: Colors.white, size: 84),
                  const SizedBox(height: 12),
                  if (widget.remoteUserId != null)
                    Text(
                      'Conectando con ${widget.remoteUserId}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  if (_peerConnection != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Semantics(
                        label: 'Duración de la llamada',
                        child: Text('⏱ $_callDuration',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 12,
            right: 12,
            child: SafeArea(
              bottom: false,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(95),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2B4461)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: _networkColor.withAlpha(35),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _networkColor.withAlpha(185)),
                      ),
                      child: Text(
                        _networkLabel,
                        style: TextStyle(
                          color: _networkColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.remoteUserId ?? 'Llamada Orbit',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      _callDuration,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (hasRemoteVideo)
            Positioned(
              top: 40,
              right: 20,
              child: Container(
                width: 110,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF3A5A7B)),
                ),
                child: RTCVideoView(_localRenderer,
                    mirror: true,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
              ),
            ),
          Positioned(
            bottom: 26,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(115),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2E4865)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _controlButton(
                            icon: micOn ? Icons.mic : Icons.mic_off,
                            color: micOn ? Colors.white : Colors.red,
                            semanticLabel: micOn
                                ? 'Micrófono activado'
                                : 'Micrófono desactivado',
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => micOn = !micOn);
                              _showBanner(
                                  micOn
                                      ? 'Micrófono activado'
                                      : 'Micrófono desactivado',
                                  micOn ? Colors.green : Colors.red);
                              _toggleMic();
                            },
                          ),
                          if (!widget.audioOnly)
                            _controlButton(
                              icon: cameraOn
                                  ? Icons.videocam
                                  : Icons.videocam_off,
                              color: cameraOn ? Colors.white : Colors.red,
                              semanticLabel: cameraOn
                                  ? 'Cámara activada'
                                  : 'Cámara desactivada',
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => cameraOn = !cameraOn);
                                _showBanner(
                                    cameraOn
                                        ? 'Cámara activada'
                                        : 'Cámara desactivada',
                                    cameraOn ? Colors.green : Colors.red);
                                _toggleCamera();
                              },
                            ),
                          _controlButton(
                            icon:
                                speakerOn ? Icons.volume_up : Icons.volume_off,
                            color: speakerOn ? Colors.white : Colors.red,
                            semanticLabel: speakerOn
                                ? 'Altavoz activado'
                                : 'Altavoz desactivado',
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => speakerOn = !speakerOn);
                              _showBanner(
                                  speakerOn
                                      ? 'Altavoz activado'
                                      : 'Altavoz desactivado',
                                  speakerOn ? Colors.green : Colors.red);
                              _toggleSpeaker();
                            },
                          ),
                          _controlButton(
                            icon: Icons.call_end,
                            color: Colors.red,
                            semanticLabel: 'Finalizar llamada',
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              Navigator.pop(context);
                            },
                          ),
                          IconButton(
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              setState(
                                  () => _controlsExpanded = !_controlsExpanded);
                            },
                            icon: Icon(
                              _controlsExpanded
                                  ? Icons.keyboard_arrow_down
                                  : Icons.keyboard_arrow_up,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      if (_controlsExpanded)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _controlButton(
                                icon: Icons.person_add,
                                color: Colors.white,
                                semanticLabel: 'Añadir contacto a llamada',
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Añadir contacto'),
                                      content: const Text(
                                          'Funcionalidad para añadir contacto a la llamada.'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(),
                                            child: const Text('Cerrar'))
                                      ],
                                    ),
                                  );
                                },
                              ),
                              _controlButton(
                                icon: Icons.link,
                                color: Colors.white,
                                semanticLabel: 'Invitar a llamada',
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Invitar a llamada'),
                                      content: const Text(
                                          'Funcionalidad para invitar a la llamada.'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(),
                                            child: const Text('Cerrar'))
                                      ],
                                    ),
                                  );
                                },
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _networkColor.withAlpha(30),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                      color: _networkColor.withAlpha(170)),
                                ),
                                child: Text(
                                  _latencyMs == null
                                      ? 'Latencia n/d'
                                      : '${_latencyMs} ms',
                                  style: TextStyle(
                                    color: _networkColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? semanticLabel,
  }) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(12),
          shape: BoxShape.circle,
        ),
        child: CameraIconButton(
          icon: icon,
          tooltip: semanticLabel ?? '',
          onTap: onTap,
        ),
      ),
    );
  }
}
