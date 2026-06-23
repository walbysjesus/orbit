import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../services/call_service.dart';

/// Pantalla que muestra llamadas entrantes
class CallReceiverScreen extends StatefulWidget {
  final String callId;
  final String callerId;
  final String callerName;
  final String? callerPhoto;
  final bool isVideo;

  const CallReceiverScreen({
    super.key,
    required this.callId,
    required this.callerId,
    required this.callerName,
    this.callerPhoto,
    required this.isVideo,
  });

  @override
  State<CallReceiverScreen> createState() => _CallReceiverScreenState();
}

class _CallReceiverScreenState extends State<CallReceiverScreen>
    with WidgetsBindingObserver {
  final _callService = CallService();
  final _firestore = FirebaseFirestore.instance;
  final _audioPlayer = AudioPlayer();

  bool _isAccepting = false;
  bool _isRejecting = false;
  bool _callExpired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startRingtone();
    _startCallTimeout();
  }

  void _startRingtone() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      // Usar sonido de sistema o asset
      await _audioPlayer.play(
        AssetSource('sounds/ringtone.mp3'),
      );
    } catch (e) {
      debugPrint('Error playing ringtone: $e');
    }
  }

  void _startCallTimeout({Duration timeout = const Duration(minutes: 1)}) {
    Future.delayed(timeout, () {
      if (mounted && !_callExpired) {
        setState(() => _callExpired = true);
        _rejectCall();
      }
    });
  }

  Future<void> _acceptCall() async {
    if (_isAccepting) return;
    setState(() => _isAccepting = true);

    try {
      await _audioPlayer.stop();

      // Obtener la sala de Firestore
      final callDoc = await _firestore.collection('calls').doc(widget.callId).get();
      final callData = callDoc.data();

      if (callData == null) {
        throw Exception('Llamada no encontrada');
      }

      final roomId = callData['roomId'] as String;

      // Aceptar llamada
      await _callService.acceptCall(
        callId: widget.callId,
        roomId: roomId,
        callerId: widget.callerId,
        isVideo: widget.isVideo,
      );

      if (!mounted) return;

      // Navegar a pantalla de video
      Navigator.of(context).pushReplacementNamed(
        '/video-call',
        arguments: {
          'roomId': roomId,
          'remoteUserId': widget.callerId,
          'remoteDisplayName': widget.callerName,
          'isVideo': widget.isVideo,
          'isCaller': false,
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isAccepting = false);
        _showError('Error al aceptar: $e');
      }
    }
  }

  Future<void> _rejectCall() async {
    if (_isRejecting) return;
    setState(() => _isRejecting = true);

    try {
      await _audioPlayer.stop();
      await _callService.rejectCall(callId: widget.callId);

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isRejecting = false);
        _showError('Error al rechazar: $e');
      }
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _audioPlayer.pause();
    } else if (state == AppLifecycleState.resumed) {
      if (!_callExpired) {
        _audioPlayer.resume();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue[700]!, Colors.blue[900]!],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Avatar y nombre
              Column(
                children: [
                  const SizedBox(height: 40),
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.white30,
                    backgroundImage: widget.callerPhoto != null
                        ? NetworkImage(widget.callerPhoto!)
                        : null,
                    child: widget.callerPhoto == null
                        ? const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 60,
                          )
                        : null,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.callerName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isVideo
                        ? 'Llamada de video entrante'
                        : 'Llamada entrante',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  if (_callExpired)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'Llamada expirada',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red[200],
                        ),
                      ),
                    ),
                ],
              ),
              // Botones de acción
              Padding(
                padding: const EdgeInsets.all(32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Rechazar
                    FloatingActionButton(
                      onPressed: _isRejecting ? null : _rejectCall,
                      backgroundColor: Colors.red,
                      child: _isRejecting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.call_end),
                    ),
                    // Aceptar
                    FloatingActionButton(
                      onPressed: _isAccepting ? null : _acceptCall,
                      backgroundColor: Colors.green,
                      child: _isAccepting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.call),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    super.dispose();
  }
}
