import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../services/call_service.dart';

/// Pantalla de video llamada en tiempo real
class VideoCallScreenProduction extends StatefulWidget {
  final String roomId;
  final String remoteUserId;
  final String remoteDisplayName;
  final bool isVideo;
  final bool isCaller;

  const VideoCallScreenProduction({
    super.key,
    required this.roomId,
    required this.remoteUserId,
    required this.remoteDisplayName,
    this.isVideo = false,
    this.isCaller = false,
  });

  @override
  State<VideoCallScreenProduction> createState() =>
      _VideoCallScreenProductionState();
}

class _VideoCallScreenProductionState extends State<VideoCallScreenProduction>
    with WidgetsBindingObserver {
  final _callService = CallService();

  // Renderizadores de video
  RTCVideoRenderer? _localVideoRenderer;
  RTCVideoRenderer? _remoteVideoRenderer;

  // Estado de llamada
  bool _isMuted = false;
  bool _isCameraDisabled = false;
  bool _isCallEnded = false;
  int _callDurationSeconds = 0;
  Timer? _durationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    try {
      // Inicializar renderizadores
      _localVideoRenderer = RTCVideoRenderer();
      _remoteVideoRenderer = RTCVideoRenderer();

      await _localVideoRenderer!.initialize();
      await _remoteVideoRenderer!.initialize();

      // Escuchar cambios de estado
      _callService.onCallStatusChanged = _onCallStatusChanged;
      _callService.onRemoteStreamAdded = _onRemoteStreamAdded;
      _callService.onError = _onCallError;

      // Setear streams
      if (widget.isVideo && _callService.localStream != null) {
        _localVideoRenderer!.srcObject = _callService.localStream;
      }

      // Iniciar temporizador de duración
      _startDurationTimer();

      setState(() {});
    } catch (e) {
      _showError('Error inicializando: $e');
      Navigator.of(context).pop();
    }
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _callDurationSeconds++);
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _onCallStatusChanged(CallStatus status) {
    debugPrint('📞 Call status: $status');
    if (status == CallStatus.ended || status == CallStatus.rejected) {
      _endCall();
    }
  }

  void _onRemoteStreamAdded() {
    debugPrint('🎥 Remote stream added');
    if (widget.isVideo && _callService.peerConnection != null) {
      _callService.peerConnection!.onTrack = (event) {
        debugPrint('🎥 Track received: ${event.track.kind}');
        if (event.track.kind == 'video') {
          _remoteVideoRenderer?.srcObject = event.streams.first;
        }
      };
    }
  }

  void _onCallError(String error) {
    _showError('Error: $error');
  }

  Future<void> _toggleMute() async {
    setState(() => _isMuted = !_isMuted);
    await _callService.toggleAudio(!_isMuted);
  }

  Future<void> _toggleCamera() async {
    setState(() => _isCameraDisabled = !_isCameraDisabled);
    await _callService.toggleVideo(!_isCameraDisabled);
  }

  Future<void> _switchCamera() async {
    try {
      await _callService.switchCamera();
      _showMessage('Cámara cambiada');
    } catch (e) {
      _showError('Error al cambiar cámara: $e');
    }
  }

  Future<void> _endCall() async {
    if (_isCallEnded) return;
    _isCallEnded = true;

    _durationTimer?.cancel();
    await _callService.endCall();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _endCall();
        return true;
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Fondo (video remoto o color)
            _buildRemoteVideo(),

            // Overlay con información
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopBar(),
            ),

            // Video local (picture-in-picture)
            Positioned(
              top: 60,
              right: 16,
              width: 120,
              height: 160,
              child: _buildLocalVideoPIP(),
            ),

            // Controles en la parte inferior
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildControls(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.remoteDisplayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDuration(_callDurationSeconds),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            // Botón de cambiar cámara (solo si es video)
            if (widget.isVideo)
              IconButton(
                onPressed: _switchCamera,
                icon: const Icon(
                  Icons.flip_camera_ios,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteVideo() {
    if (!widget.isVideo) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[700],
                child: const Icon(
                  Icons.person,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.remoteDisplayName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: _remoteVideoRenderer != null
          ? RTCVideoView(
              _remoteVideoRenderer!,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            )
          : const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
    );
  }

  Widget _buildLocalVideoPIP() {
    if (!widget.isVideo) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 2),
        borderRadius: BorderRadius.circular(8),
        color: Colors.black,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: _localVideoRenderer != null
            ? RTCVideoView(
                _localVideoRenderer!,
                mirror: true,
                objectFit:
                    RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            : Container(
                color: Colors.grey[700],
                child: const Center(
                  child: Icon(
                    Icons.videocam_off,
                    color: Colors.white,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Mute/Unmute
            FloatingActionButton(
              onPressed: _toggleMute,
              heroTag: 'mute',
              backgroundColor:
                  _isMuted ? Colors.red : Colors.blue,
              child: Icon(_isMuted ? Icons.mic_off : Icons.mic),
            ),
            // Toggle Camera
            if (widget.isVideo)
              FloatingActionButton(
                onPressed: _toggleCamera,
                heroTag: 'camera',
                backgroundColor: _isCameraDisabled
                    ? Colors.red
                    : Colors.blue,
                child: Icon(
                  _isCameraDisabled
                      ? Icons.videocam_off
                      : Icons.videocam,
                ),
              ),
            // End Call
            FloatingActionButton(
              onPressed: _endCall,
              heroTag: 'end',
              backgroundColor: Colors.red,
              child: const Icon(Icons.call_end),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Pausar video cuando app va a background
      if (widget.isVideo && _localVideoRenderer != null) {
        _localVideoRenderer!.srcObject = null;
      }
    } else if (state == AppLifecycleState.resumed) {
      // Reanudar video cuando app vuelve al foreground
      if (widget.isVideo &&
          _callService.localStream != null &&
          _localVideoRenderer != null) {
        _localVideoRenderer!.srcObject = _callService.localStream;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _durationTimer?.cancel();
    _localVideoRenderer?.dispose();
    _remoteVideoRenderer?.dispose();
    _callService.dispose();
    super.dispose();
  }
}
