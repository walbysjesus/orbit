import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/scheduler.dart';
import '../../services/simple_signaling.dart';

// Variables globales eliminadas, deben estar dentro del State

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({super.key});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late final SimpleSignaling _signaling;
  RTCPeerConnection? _peerConnection;
  final String _wsUrl = 'ws://localhost:8080'; // Cambia por tu servidor real

  late Stopwatch _stopwatch;
  late final Ticker _ticker;
  String _callDuration = '00:00';

  // flutter_webrtc
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  MediaStream? _localStream;

  @override
  void initState() {
    _signaling = SimpleSignaling(_wsUrl);
    _signaling.connect();
    _signaling.onMessage = _handleSignalingMessage;
    super.initState();
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
    _initRenderers();
    _startLocalStream();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _stopwatch.stop();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _startLocalStream() async {
    final mediaConstraints = {
      'audio': true,
      'video': {
        'facingMode': 'user',
        'width': 640,
        'height': 480,
      },
    };
    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _localRenderer.srcObject = _localStream;
      await _createPeerConnection();
      await _peerConnection?.addStream(_localStream!);
      // Solo para el iniciador
      var offer = await _peerConnection?.createOffer();
      await _peerConnection?.setLocalDescription(offer!);
      _signaling.send({
        'type': 'offer',
        'sdp': offer?.sdp,
      });
    } catch (e) {
      _showBanner('Error al iniciar cámara/micrófono', Colors.redAccent, persistent: true, onRetry: _startLocalStream);
    }
  }

  Future<void> _createPeerConnection() async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    };
    _peerConnection = await createPeerConnection(config);
    _peerConnection?.onAddStream = (stream) {
      setState(() {
        _remoteRenderer.srcObject = stream;
      });
    };
    _peerConnection?.onIceCandidate = (candidate) {
      _signaling.send({
        'type': 'candidate',
        'candidate': candidate.toMap(),
      });
    };
  }

  void _handleSignalingMessage(Map<String, dynamic> msg) async {
    switch (msg['type']) {
      case 'offer':
        if (_peerConnection == null) await _createPeerConnection();
        await _peerConnection?.setRemoteDescription(RTCSessionDescription(msg['sdp'], 'offer'));
        var answer = await _peerConnection?.createAnswer();
        await _peerConnection?.setLocalDescription(answer!);
        _signaling.send({
          'type': 'answer',
          'sdp': answer?.sdp,
        });
        break;
      case 'answer':
        await _peerConnection?.setRemoteDescription(RTCSessionDescription(msg['sdp'], 'answer'));
        break;
      case 'candidate':
        var cand = msg['candidate'];
        await _peerConnection?.addCandidate(RTCIceCandidate(cand['candidate'], cand['sdpMid'], cand['sdpMLineIndex']));
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

  void _showBanner(String message, Color color, {bool persistent = false, VoidCallback? onRetry}) {
    setState(() {
      _activeBanner = MaterialBanner(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        actions: [
          if (onRetry != null)
            TextButton(
              child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
              onPressed: () {
                setState(() { _activeBanner = null; });
                onRetry();
              },
            ),
          TextButton(
            child: const Text('Cerrar', style: TextStyle(color: Colors.white)),
            onPressed: () {
              setState(() { _activeBanner = null; });
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
          setState(() { _activeBanner = null; });
        }
      });
    }
  }
  bool micOn = true;
  bool speakerOn = false;
  bool cameraOn = true;


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_activeBanner != null) Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _activeBanner!,
          ),
          // VIDEO REMOTO
          Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 320,
                    height: 220,
                    child: RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    label: 'Duración de la llamada',
                    child: Text('⏱ $_callDuration', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          // VIDEO LOCAL
          Positioned(
            top: 40,
            right: 20,
            child: Container(
              width: 110,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: RTCVideoView(_localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
            ),
          ),
          // CONTROLES
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _controlButton(
                  icon: micOn ? Icons.mic : Icons.mic_off,
                  color: micOn ? Colors.white : Colors.red,
                  semanticLabel: micOn ? 'Micrófono activado' : 'Micrófono desactivado',
                  onTap: () {
                    setState(() => micOn = !micOn);
                    _showBanner(micOn ? 'Micrófono activado' : 'Micrófono desactivado', micOn ? Colors.green : Colors.red);
                    _toggleMic();
                  },
                ),
                _controlButton(
                  icon: cameraOn ? Icons.videocam : Icons.videocam_off,
                  color: cameraOn ? Colors.white : Colors.red,
                  semanticLabel: cameraOn ? 'Cámara activada' : 'Cámara desactivada',
                  onTap: () {
                    setState(() => cameraOn = !cameraOn);
                    _showBanner(cameraOn ? 'Cámara activada' : 'Cámara desactivada', cameraOn ? Colors.green : Colors.red);
                    _toggleCamera();
                  },
                ),
                _controlButton(
                  icon: speakerOn ? Icons.volume_up : Icons.volume_off,
                  color: speakerOn ? Colors.white : Colors.red,
                  semanticLabel: speakerOn ? 'Altavoz activado' : 'Altavoz desactivado',
                  onTap: () {
                    setState(() => speakerOn = !speakerOn);
                    _showBanner(speakerOn ? 'Altavoz activado' : 'Altavoz desactivado', speakerOn ? Colors.green : Colors.red);
                    _toggleSpeaker();
                  },
                ),
                _controlButton(
                  icon: Icons.call_end,
                  color: Colors.red,
                  semanticLabel: 'Finalizar llamada',
                  onTap: () => Navigator.pop(context),
                ),
              ],
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
      child: GestureDetector(
        onTap: onTap,
        child: CircleAvatar(
          radius: 28,
          backgroundColor: Colors.black54,
          child: Icon(icon, color: color, size: 28),
        ),
      ),
    );
  }
}
