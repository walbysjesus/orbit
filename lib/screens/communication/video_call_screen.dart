import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' hide AndroidAudioMode;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/config.dart';
import '../../services/auth_service.dart';
import '../../services/call_diagnostics_service.dart';
import '../../services/call_session_service.dart';
import '../../services/fcm_service.dart';
import '../../services/network_service.dart';
import '../../services/webrtc_service.dart';
import '../../services/firestore_signaling.dart';
import '../../services/turn_stun_config.dart';
import '../../utils/camera_icon_button.dart';
import '../../utils/error_presenter.dart';

// Variables globales eliminadas, deben estar dentro del State

class VideoCallScreen extends StatefulWidget {
  /// ID Ãºnico de la sala WebRTC. Si no se provee, la pantalla genera uno temporal.
  final String? roomId;

  /// UID del usuario remoto (para mostrar en UI y enrutar sala).
  final String? remoteUserId;

  /// Nombre conocido del usuario remoto, si ya fue resuelto antes de abrir la llamada.
  final String? initialRemoteDisplayName;

  /// Si es true, inicia una llamada de voz (sin video local/remoto).
  final bool audioOnly;

  /// Fuerza rol de iniciador para evitar oferta simultÃ¡nea.
  final bool? isCaller;

  /// ID de sesiÃ³n en Firestore para seguimiento de estado (ringing/accepted/ended).
  final String? callSessionId;

  const VideoCallScreen({
    super.key,
    this.roomId,
    this.remoteUserId,
    this.initialRemoteDisplayName,
    this.audioOnly = false,
    this.isCaller,
    this.callSessionId,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen>
    with WidgetsBindingObserver {
  // ========== MEMORY & STABILITY CONSTANTS ==========
  static const int _maxPendingIceCandidates = 300;

  Future<void> _toggleVideo() async {
    setState(() => _videoEnabled = !_videoEnabled);
    if (_localStream == null) return;
    final videoTracks = _localStream!.getVideoTracks();
    for (final track in videoTracks) {
      track.enabled = _videoEnabled;
    }
    if (_videoEnabled && videoTracks.isEmpty) {
      // Si no hay track de video, intenta agregarlo
      final videoStream =
          await navigator.mediaDevices.getUserMedia({'video': true});
      final videoTrack = videoStream.getVideoTracks().first;
      await _localStream!.addTrack(videoTrack);
      await _peerConnection?.addTrack(videoTrack, _localStream!);
    }
    if (!_videoEnabled && videoTracks.isNotEmpty) {
      for (final track in videoTracks) {
        await track.stop();
        await _localStream!.removeTrack(track);
      }
    }
    if (!mounted) return; // lifecycle safety fix
    setState(() {});
  }

  bool _videoEnabled = false;
  late final FirestoreSignaling _signaling;
  RTCPeerConnection? _peerConnection;
  bool _offerSent = false;
  String? _remoteDisplayName;
  String? _remoteOrbitNumber;

  late String _roomId;
  String? _localUserId;
  bool _isCaller = false;
  String? _callSessionId;
  bool _remotePeerJoined = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _callSub;
  Timer? _networkTimer;
  Timer? _iceRestartTimer;
  Timer? _iceRecoveryTimeoutTimer;
  Timer? _iceHeartbeatTimer;
  Timer? _ringTimeoutTimer;
  Timer? _connectTimeoutTimer;
  String _networkLabel = 'Analizando se\u00f1al...';
  Color _networkColor = const Color(0xFF8FA9C2);
  bool _isSatelliteNetwork = false;
  int? _latencyMs;
  NetworkQuality _networkQuality = NetworkQuality.unknown;
  bool _videoDegraded = false;
  bool _controlsExpanded = false;
  RealtimeUxState _callRealtimeState = RealtimeUxState.queued;
  String _callRealtimeMessage = 'Iniciando llamada...';
  String _sessionStatus = 'n/d';
  String _iceStatus = 'n/d';
  String _pcStatus = 'n/d';
  String _signalStatus = 'n/d';
  String _localPathType = 'n/d';
  String _remotePathType = 'n/d';
  int _localCandidateCount = 0;
  int _remoteCandidateCount = 0;
  bool _remoteDescriptionSet = false;
  final List<RTCIceCandidate> _pendingRemoteCandidates = <RTCIceCandidate>[];
  final NetworkService _networkService = NetworkService();
  CallAdaptiveProfile _adaptiveProfile = const CallAdaptiveProfile(
    maxWidth: 1280,
    maxHeight: 720,
    maxFps: 24,
    targetBitrateKbps: 1200,
    minBitrateKbps: 350,
    pauseVideo: false,
    batterySaver: false,
    thermalLevel: ThermalLevel.cool,
  );
  bool _batterySaverMode = false;
  ThermalLevel _thermalLevel = ThermalLevel.cool;
  String? _lastAdaptiveProfileKey;

  // ========== PHASE 2: ICE RECONNECTION LOGIC ==========
  int _iceReconnectAttempts = 0;
  static const int _maxIceReconnectAttempts = 6;
  static const int _minIceReconnectDelayMs = 2000; // 2 seconds
  static const int _maxIceReconnectDelayMs = 30000;
  static const int _maxReconnectStormPerMinute = 8;
  static const Duration _restartSignalCooldown = Duration(seconds: 4);
  static const Duration _iceRecoveryTimeout = Duration(seconds: 18);
  static const Duration _iceHeartbeatInterval = Duration(seconds: 8);
  static const int _heartbeatUnhealthyThreshold = 2;
  final Random _random = Random();
  bool _iceRecoveryInProgress = false;
  DateTime _restartStormWindowStart = DateTime.now();
  int _restartStormCount = 0;
  DateTime? _lastRestartSignalAt;
  DateTime? _lastRecoveryTriggerAt;
  int _heartbeatUnhealthyTicks = 0;
  final Set<String> _handledRestartRequestIds = <String>{};

  late Stopwatch _stopwatch;
  late final Ticker _ticker;
  String _callDuration = '00:00';

  // flutter_webrtc
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  final AudioPlayer _ringPlayer = AudioPlayer();
  MediaStream? _localStream;
  bool _ringtonePlaying = false;
  bool _incomingRingtonePlaying = false;
  bool _incomingSessionAcceptRequested = false;
  bool _roomCleanupStarted = false;
  bool _screenCloseRequested = false;
  bool _batteryHintShown = false;
  bool _oemHintShown = false;
  bool _runtimeInitialized = false;
  bool _signalingConnectedOnce = false;
  bool _connectionEstablishedOnce = false;
  static const MethodChannel _androidVoipChannel = MethodChannel('orbit/voip');

  @override
  void initState() {
    _videoEnabled = !widget.audioOnly;
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize _roomId early before any logging
    _roomId = widget.roomId ?? 'room_${DateTime.now().millisecondsSinceEpoch}';

    // ========== PHASE 2: TURN/STUN VALIDATION ==========
    // Block calls in release mode if TURN not configured
    final turnError = TurnStunConfig.shouldBlockCallInRelease();
    if (turnError != null) {
      _showBanner(
        turnError,
        Colors.red,
        persistent: true,
      );
      // Schedule pop after showing error
      Future.delayed(const Duration(milliseconds: 500), () {
        unawaited(_closeScreenSafely());
      });
      return;
    }

    // Log diagnostic info for debugging
    _logRtc(TurnStunConfig.getDiagnosticInfo());

    _localUserId = AuthService.getCurrentUser()?.uid;
    _remoteDisplayName = widget.initialRemoteDisplayName?.trim();
    _roomId = _resolveRoomId();
    _isCaller = widget.isCaller ?? _resolveCallerRole();
    _callSessionId = widget.callSessionId;
    _signaling = FirestoreSignaling(roomId: _roomId, isCaller: _isCaller);
    _androidVoipChannel.setMethodCallHandler(_handleNativeVoipEvent);
    unawaited(_initNativeVoipPlatform());
    speakerOn = widget.audioOnly;
    unawaited(_configureAudioRouting());
    _stopwatch = Stopwatch();
    _ticker = Ticker((_) {
      if (mounted && _stopwatch.isRunning) {
        setState(() {
          final seconds = _stopwatch.elapsed.inSeconds;
          final min = (seconds ~/ 60).toString().padLeft(2, '0');
          final sec = (seconds % 60).toString().padLeft(2, '0');
          _callDuration = '$min:$sec';
        });
      }
    });
    _ticker.start();
    _runtimeInitialized = true;
    _showRealtimeConfigWarnings();
    unawaited(_loadRemoteUserSummary());
    _initCall();
    _initCallSession();
    unawaited(_refreshNetworkStatus());
    _networkTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(_refreshNetworkStatus()),
    );
  }

  void _showRealtimeConfigWarnings() {
    if (!kDebugMode) return;
    final issues = getRealtimeConfigIssues(forRelease: false);
    if (issues.isEmpty) return;
    _showBanner(
      'ConfiguraciÃ³n recomendada pendiente: ${issues.join(' Â· ')}',
      Colors.orangeAccent,
      persistent: true,
    );
  }

  Future<void> _refreshNetworkStatus() async {
    final quality = await _networkService.getNetworkQuality();
    final latency = await _networkService.measureLatencyMs();
    final isSatellite = await _networkService.isSatelliteConnected();

    String label;
    Color color;
    switch (quality) {
      case NetworkQuality.none:
        label = 'Sin seÃ±al';
        color = const Color(0xFFE16B6B);
        break;
      case NetworkQuality.low:
        label = 'Inestable';
        color = const Color(0xFFFFB46A);
        break;
      case NetworkQuality.medium:
        label = 'SeÃ±al media';
        color = const Color(0xFFECCB6A);
        break;
      case NetworkQuality.high:
        label = 'SeÃ±al alta';
        color = const Color(0xFF63D9B3);
        break;
      case NetworkQuality.unknown:
        label = 'SeÃ±al desconocida';
        color = const Color(0xFF8FA9C2);
        break;
    }

    // Si es satÃ©lite, agregar indicador
    if (isSatellite) {
      label = '$label Â· ðŸ›°ï¸ SatÃ©lite';
    }

    final nextProfile = _networkService.getAdaptiveCallProfile(
      audioOnly: widget.audioOnly,
      quality: quality,
      isSatellite: isSatellite,
      latencyMs: latency,
      reconnectAttempts: _iceReconnectAttempts,
      unhealthyHeartbeatTicks: _heartbeatUnhealthyTicks,
      batterySaverHint:
          _stopwatch.isRunning && _stopwatch.elapsed.inMinutes >= 8,
    );

    if (nextProfile.batterySaver) {
      label = '$label Â· ahorro';
    }
    if (nextProfile.thermalLevel == ThermalLevel.hot ||
        nextProfile.thermalLevel == ThermalLevel.critical) {
      label = '$label Â· tÃ©rmico alto';
    }

    if (!mounted) return;
    setState(() {
      _networkLabel = latency == null ? label : '$label Â· $latency ms';
      _networkColor = color;
      _latencyMs = latency;
      _isSatelliteNetwork = isSatellite;
      _networkQuality = quality;
      _adaptiveProfile = nextProfile;
      _batterySaverMode = nextProfile.batterySaver;
      _thermalLevel = nextProfile.thermalLevel;
      if (quality == NetworkQuality.none) {
        _callRealtimeState = RealtimeUxState.offline;
        _callRealtimeMessage =
            'Sin internet. Intentando recuperar la llamada...';
      } else if (_iceRecoveryInProgress) {
        _callRealtimeState = RealtimeUxState.reconnecting;
        _callRealtimeMessage = 'Reconectando llamada en tiempo real...';
      } else {
        _callRealtimeState = RealtimeUxState.online;
        _callRealtimeMessage = 'Llamada estable';
      }
    });

    _logRtc(
        'adaptive_profile bitrate=${nextProfile.targetBitrateKbps}kbps min=${nextProfile.minBitrateKbps}kbps res=${nextProfile.maxWidth}x${nextProfile.maxHeight} fps=${nextProfile.maxFps} pauseVideo=${nextProfile.pauseVideo} batterySaver=${nextProfile.batterySaver} thermal=${nextProfile.thermalLevel.name}');

    _trackAdaptiveProfileTransition(nextProfile);

    await _applyAdaptiveMediaProfile();
  }

  void _trackAdaptiveProfileTransition(CallAdaptiveProfile profile) {
    final tier = profile.pauseVideo
        ? 'critical'
        : (profile.batterySaver ? 'saver' : 'high');
    final key = '$tier|${profile.maxWidth}x${profile.maxHeight}|'
        '${profile.maxFps}|${profile.targetBitrateKbps}|'
        '${profile.minBitrateKbps}|${profile.thermalLevel.name}';
    if (_lastAdaptiveProfileKey == key) return;

    _lastAdaptiveProfileKey = key;
    unawaited(
      _auditCall(
        'adaptive_profile_changed',
        extra: {
          'adaptiveTier': tier,
          'adaptiveWidth': profile.maxWidth,
          'adaptiveHeight': profile.maxHeight,
          'adaptiveFps': profile.maxFps,
          'adaptiveTargetBitrateKbps': profile.targetBitrateKbps,
          'adaptiveMinBitrateKbps': profile.minBitrateKbps,
          'adaptivePauseVideo': profile.pauseVideo,
          'adaptiveBatterySaver': profile.batterySaver,
          'adaptiveThermalLevel': profile.thermalLevel.name,
        },
      ),
    );
  }

  Future<void> _applyAdaptiveMediaProfile() async {
    if (widget.audioOnly || _localStream == null) return;

    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isEmpty) return;

    if (_adaptiveProfile.pauseVideo) {
      for (final track in videoTracks) {
        track.enabled = false;
      }
      if (mounted) {
        setState(() {
          _videoDegraded = true;
        });
      }
      _showBanner(
        'Modo resiliente: video pausado para priorizar audio/datos/temperatura',
        Colors.orangeAccent,
      );
      return;
    }

    for (final track in videoTracks) {
      track.enabled = true;
      try {
        await track.applyConstraints({
          'width': _adaptiveProfile.maxWidth,
          'height': _adaptiveProfile.maxHeight,
          'frameRate': _adaptiveProfile.maxFps,
        });
      } catch (e) {
        _logRtc('video applyConstraints failed: $e');
      }
    }

    final shouldMarkDegraded = _adaptiveProfile.maxHeight <= 480 ||
        _adaptiveProfile.maxFps <= 18 ||
        _adaptiveProfile.batterySaver;
    if (mounted) {
      setState(() {
        _videoDegraded = shouldMarkDegraded;
      });
    }
    if (!shouldMarkDegraded && mounted) {
      _showBanner(
        'Red recuperada: video reactivado',
        Colors.green,
      );
    }
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
    _screenCloseRequested = true;
    _androidVoipChannel.setMethodCallHandler(null);
    WidgetsBinding.instance.removeObserver(this);
    // ========== PHASE 1: COMPREHENSIVE MEMORY CLEANUP ==========
    // 1. Stop active sessions and timers
    unawaited(_stopOutgoingRingtone());
    unawaited(_stopIncomingRingtone());
    unawaited(_endSessionIfNeeded());
    unawaited(_cleanupSignalingRoomIfNeeded());

    // 2. Cancel all stream subscriptions
    _callSub?.cancel();
    _callSub = null;

    // 3. Cancel all timers (prevents background execution)
    _networkTimer?.cancel();
    _iceRestartTimer?.cancel();
    _iceRecoveryTimeoutTimer?.cancel();
    _iceHeartbeatTimer?.cancel();
    _ringTimeoutTimer?.cancel();
    _connectTimeoutTimer?.cancel();

    // 4. Clear ICE buffer to prevent memory leak
    _pendingRemoteCandidates.clear();

    // 5. Stop all audio/video tracks (releases hardware resources)
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        try {
          track.stop();
        } catch (e) {
          _logRtc('âš ï¸ Error stopping track: $e');
        }
      }
      try {
        _localStream!.dispose();
      } catch (e) {
        _logRtc('âš ï¸ Error disposing stream: $e');
      }
      _localStream = null;
    }

    // 6. Clear renderers and close peer connection
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
    try {
      _peerConnection?.close();
      _peerConnection?.dispose();
    } catch (e) {
      _logRtc('âš ï¸ Error closing peer connection: $e');
    }
    _peerConnection = null;

    // 7. Stop signaling
    if (_runtimeInitialized) {
      try {
        unawaited(_stopNativeVoipForeground());
        unawaited(_setNativeNormalAudioMode());
        unawaited(_signaling.close());
      } catch (e) {
        _logRtc('âš ï¸ Error closing signaling: $e');
      }
    }

    // 8. Stop animation and audio
    if (_runtimeInitialized) {
      _ticker.dispose();
      _stopwatch.stop();
    }

    // 9. Properly dispose audio player (must await to ensure cleanup)
    try {
      unawaited(_ringPlayer.stop());
      unawaited(_ringPlayer.release());
      unawaited(_ringPlayer.dispose());
    } catch (e) {
      _logRtc('âš ï¸ Error disposing audio player: $e');
    }

    // 10. Dispose renderers
    try {
      _localRenderer.dispose();
      _remoteRenderer.dispose();
    } catch (e) {
      _logRtc('âš ï¸ Error disposing renderers: $e');
    }

    _ringtonePlaying = false;
    _remoteDescriptionSet = false;
    _offerSent = false;

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      unawaited(_startNativeVoipForeground());
      return;
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(_setNativeVoipAudioMode());
      unawaited(_refreshNetworkStatus());
      final iceState = _peerConnection?.iceConnectionState;
      final healthy =
          iceState == RTCIceConnectionState.RTCIceConnectionStateConnected ||
              iceState == RTCIceConnectionState.RTCIceConnectionStateCompleted;
      if (!healthy && mounted) {
        _requestIceRecovery(
          reason: 'app_resumed_recovery',
          trigger: 'lifecycle_resumed',
        );
      }
    }
  }

  Future<void> _initNativeVoipPlatform() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    try {
      await _androidVoipChannel.invokeMethod('ensureVoipRuntimeSetup');
      await _setNativeVoipAudioMode();
      await _startNativeVoipForeground();
      final report =
          await _androidVoipChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getVoipCapabilityReport',
      );
      _logRtc('android_voip_report=$report');

      final ignoringBattery = await _androidVoipChannel
              .invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
          false;
      if (!ignoringBattery && mounted && !_batteryHintShown && kDebugMode) {
        _batteryHintShown = true;
        _showBanner(
          'Recomendado: desactivar optimizaciÃ³n de baterÃ­a para llamadas estables',
          Colors.orangeAccent,
          onRetry: () {
            unawaited(
              _androidVoipChannel
                  .invokeMethod('openBatteryOptimizationSettings'),
            );
          },
        );
      }

      final oemRestrictionDetected = (report?['autoStartRestricted'] == true) ||
          (report?['autostartRestricted'] == true) ||
          (report?['backgroundRestricted'] == true);
      if (oemRestrictionDetected && mounted && !_oemHintShown && kDebugMode) {
        _oemHintShown = true;
        _showBanner(
          'Activa auto-inicio en ajustes OEM para mejorar recepciÃ³n de llamadas',
          Colors.blueGrey,
          onRetry: () {
            unawaited(
              _androidVoipChannel.invokeMethod('openOemAutostartSettings'),
            );
          },
        );
      }
    } catch (e) {
      _logRtc('android voip helper unavailable: $e');
    }
  }

  Future<void> _setNativeVoipAudioMode() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    try {
      await _androidVoipChannel.invokeMethod('setVoipAudioMode', {
        'speakerOn': speakerOn,
      });
    } catch (e) {
      _logRtc('setVoipAudioMode failed: $e');
    }
  }

  Future<void> _setNativeNormalAudioMode() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    try {
      await _androidVoipChannel.invokeMethod('setNormalAudioMode');
    } catch (e) {
      _logRtc('setNormalAudioMode failed: $e');
    }
  }

  Future<void> _startNativeVoipForeground() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    try {
      await _androidVoipChannel.invokeMethod('startVoipForeground', {
        'title': 'Llamada Orbit en curso',
      });
    } catch (e) {
      _logRtc('startVoipForeground failed: $e');
    }
  }

  Future<void> _stopNativeVoipForeground() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    try {
      await _androidVoipChannel.invokeMethod('stopVoipForeground');
    } catch (e) {
      _logRtc('stopVoipForeground failed: $e');
    }
  }

  Future<void> _handleNativeVoipEvent(MethodCall call) async {
    switch (call.method) {
      case 'onNativeCallAnswered':
        _logRtc('native call answered event=${call.arguments}');
        if (_callSessionId != null && _callSessionId!.isNotEmpty) {
          unawaited(CallSessionService.acceptSession(_callSessionId!));
        }
        _startCallTimerIfNeeded();
        if (_isCaller && _localStream != null) {
          unawaited(_createAndSendOffer());
        }
        break;
      case 'onNativeCallEnded':
        _logRtc('native call ended event=${call.arguments}');
        if (_callSessionId != null && _callSessionId!.isNotEmpty) {
          unawaited(CallSessionService.endSession(_callSessionId!));
        }
        unawaited(_closeScreenSafely());
        break;
      case 'onPushKitIncoming':
        _logRtc('pushkit incoming payload=${call.arguments}');
        break;
      case 'onPushKitToken':
        _logRtc('pushkit token event=${call.arguments}');
        break;
      default:
        _logRtc('native voip event ignored=${call.method}');
        break;
    }
  }

  Future<void> _initCallSession() async {
    if (_callSessionId != null && _callSessionId!.isNotEmpty) {
      if (_isCaller) {
        _startOutgoingRingtone();
      } else {
        unawaited(_acceptIncomingSessionIfNeeded(_callSessionId!));
      }
      _listenCallSession(_callSessionId!);
      return;
    }

    if (!_isCaller) return;
    final remote = widget.remoteUserId?.trim();
    if (remote == null || remote.isEmpty) return;

    try {
      final createdId = await CallSessionService.createOutgoingSession(
        calleeId: remote,
        audioOnly: widget.audioOnly,
      );
      if (!mounted) return;
      setState(() => _callSessionId = createdId);
      unawaited(_auditCall('session_created',
          extra: {'audioOnly': widget.audioOnly}));
      _startOutgoingRingtone();
      _listenCallSession(createdId);
      _armConnectTimeout();

      // Timer: si en 30s no contestÃ³, cancelar y volver.
      _ringTimeoutTimer = Timer(const Duration(seconds: 30), () async {
        if (!mounted) return; // lifecycle safety fix
        _stopOutgoingRingtone();
        await CallSessionService.cancelExpiredRinging(createdId);
        if (!mounted) return; // lifecycle safety fix
        _showBanner('Sin respuesta', Colors.blueGrey);
        await Future.delayed(const Duration(seconds: 1));
        await _closeScreenSafely();
      });
    } catch (_) {
      if (!mounted) return;
      unawaited(_auditCall('session_create_failed'));
      _showBanner('No se pudo crear sesiÃ³n de llamada', Colors.orangeAccent);
    }
  }

  void _listenCallSession(String callId) {
    _callSub?.cancel();
    _callSub = CallSessionService.sessionStream(callId).listen((snap) {
      if (!mounted || !snap.exists) return;
      final data = snap.data();
      final status = (data?['status'] as String?)?.trim();
      if (status == null || status.isEmpty) return;

      setState(() => _sessionStatus = status);
      unawaited(_auditCall('session_status', extra: {'status': status}));

      if (status == 'accepted') {
        _ringTimeoutTimer?.cancel();
        unawaited(_stopIncomingRingtone());
        _stopOutgoingRingtone();
        _armConnectTimeout();
        _startCallTimerIfNeeded();
        _remotePeerJoined = true;
        if (_isCaller && _localStream != null) {
          unawaited(_createAndSendOffer());
        }
      } else if (status == 'ringing') {
        if (_isCaller) {
          _startOutgoingRingtone();
        } else {
          unawaited(_acceptIncomingSessionIfNeeded(callId));
          unawaited(_startIncomingRingtone());
        }
      } else if (status == 'rejected') {
        _connectTimeoutTimer?.cancel();
        unawaited(_stopIncomingRingtone());
        _stopOutgoingRingtone();
        unawaited(_cleanupSignalingRoomIfNeeded());
        _showBanner('La llamada fue rechazada', Colors.orangeAccent);
        unawaited(_closeScreenSafely());
      } else if (status == 'missed') {
        _connectTimeoutTimer?.cancel();
        unawaited(_stopIncomingRingtone());
        _stopOutgoingRingtone();
        unawaited(_cleanupSignalingRoomIfNeeded());
        _showBanner('No contestaron la llamada', Colors.blueGrey);
        unawaited(_closeScreenSafely());
      } else if (status == 'ended') {
        _connectTimeoutTimer?.cancel();
        unawaited(_stopIncomingRingtone());
        _stopOutgoingRingtone();
        unawaited(_cleanupSignalingRoomIfNeeded());
        _showBanner('La llamada finalizÃ³', Colors.blueGrey);
        unawaited(_closeScreenSafely());
      }
    });
  }

  void _armConnectTimeout() {
    _connectTimeoutTimer?.cancel();
    _connectTimeoutTimer = Timer(const Duration(seconds: 45), () async {
      if (!mounted || _stopwatch.isRunning) return;
      if (mounted) {
        setState(() {
          _callRealtimeState = RealtimeUxState.timeout;
          _callRealtimeMessage = 'Timeout de conexiÃ³n. Reintentando...';
        });
      }
      _logRtc('timeout: no se establecio conexion en 45s');
      unawaited(_auditCall('connect_timeout'));
      final callId = _callSessionId;
      if (callId != null && callId.isNotEmpty) {
        await CallSessionService.cancelExpiredRinging(callId);
      }
      if (!mounted) return; // lifecycle safety fix
      await _cleanupSignalingRoomIfNeeded();
      if (!mounted) return;
      _showBanner('No se pudo establecer la llamada', Colors.orangeAccent);
      await Future.delayed(const Duration(seconds: 1));
      await _closeScreenSafely();
    });
  }

  void _startOutgoingRingtone() {
    if (!_isCaller || _ringtonePlaying) return;
    _ringtonePlaying = true;
    unawaited(() async {
      if (!mounted) return; // lifecycle safety fix
      try {
        await _setNativeNormalAudioMode();
        // Configurar AudioContext para Android: modo RINGTONE con usage NOTIFICATION_RINGTONE
        // permite sonar aunque flutter_webrtc haya tomado el audio focus.
        await _ringPlayer.setAudioContext(
          AudioContext(
            android: AudioContextAndroid(
              audioMode: AndroidAudioMode.normal,
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.notificationRingtone,
              audioFocus: AndroidAudioFocus.gain,
            ),
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.playback,
              options: [
                AVAudioSessionOptions.mixWithOthers,
              ],
            ),
          ),
        );
        await _ringPlayer.setReleaseMode(ReleaseMode.loop);
        await _ringPlayer.setVolume(1.0);
        await _ringPlayer.play(AssetSource('audio/outgoing_ring.wav'));
      } catch (e) {
        _ringtonePlaying = false;
        debugPrint('Ringtone error: $e');
        SystemSound.play(SystemSoundType.alert);
      }
    }());
  }

  Future<void> _startIncomingRingtone() async {
    if (_isCaller || _incomingRingtonePlaying) return;
    _incomingRingtonePlaying = true;
    try {
      await _setNativeNormalAudioMode();
      await _ringPlayer.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            audioMode: AndroidAudioMode.normal,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.notificationRingtone,
            audioFocus: AndroidAudioFocus.gain,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: [
              AVAudioSessionOptions.mixWithOthers,
            ],
          ),
        ),
      );
      await _ringPlayer.setReleaseMode(ReleaseMode.loop);
      await _ringPlayer.setVolume(1.0);
      await _ringPlayer.play(AssetSource('audio/outgoing_ring.wav'));
    } catch (e) {
      _incomingRingtonePlaying = false;
      debugPrint('Incoming ringtone error: $e');
      SystemSound.play(SystemSoundType.alert);
    }
  }

  Future<void> _stopIncomingRingtone() async {
    if (!_incomingRingtonePlaying) return;
    _incomingRingtonePlaying = false;
    try {
      await _ringPlayer.stop();
    } catch (_) {}
    unawaited(_setNativeVoipAudioMode());
  }

  Future<void> _stopOutgoingRingtone() async {
    if (!_ringtonePlaying) return;
    _ringtonePlaying = false;
    try {
      await _ringPlayer.stop();
    } catch (_) {}
    unawaited(_setNativeVoipAudioMode());
  }

  Future<void> _closeScreenSafely({Duration delay = Duration.zero}) async {
    if (_screenCloseRequested) return;
    _screenCloseRequested = true;
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    }
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

      // Mostrar advertencia si estÃ¡ en satÃ©lite
      if (_isSatelliteNetwork) {
        _showBanner(
          'ðŸ›°ï¸ Conectado vÃ­a satÃ©lite: Alta latencia esperada (~500ms+)',
          Colors.amber,
          persistent: false,
        );
      }

      await _initRenderers();
      if (!mounted) return; // lifecycle safety fix
      _signaling.onMessage = _handleSignalingMessage;
      _signaling.onConnectionChanged = (connected) {
        _logRtc('signaling connectionChanged=$connected');
        if (connected) {
          _signalingConnectedOnce = true;
        }
      };
      _signaling.onError = (error) {
        if (!mounted) return;
        final normalized = error.trim().toLowerCase();
        if (normalized.contains('reconectando')) {
          if (!_signalingConnectedOnce || !_connectionEstablishedOnce) {
            return;
          }
          setState(() {
            _callRealtimeState = RealtimeUxState.reconnecting;
            _callRealtimeMessage = 'Reconectando señalización...';
          });
          return;
        }
        if (normalized.contains('sin conexión')) {
          setState(() {
            _callRealtimeState = RealtimeUxState.offline;
            _callRealtimeMessage = 'Sin conexión de señalización';
          });
          return;
        }
        _showBanner(error, Colors.redAccent);
      };
      // Iniciar stream local ANTES de conectar seÃ±alizaciÃ³n
      // para que el PeerConnection tenga tracks listos antes de procesar SDP.
      final permissionsOk = await _ensureMediaPermissions();
      if (!mounted) return; // lifecycle safety fix
      if (!permissionsOk) {
        unawaited(_auditCall('permissions_denied'));
        _showBanner(
            'Permisos de micrÃ³fono/cÃ¡mara requeridos', Colors.redAccent,
            persistent: true);
        return;
      }

      await _startLocalStream();
      if (!mounted) return; // lifecycle safety fix

      // Reintentar connect con backoff para zonas remotas/satÃ©lite
      await _connectSignalingWithRetry();
      _logRtc('signaling conectado room=$_roomId caller=$_isCaller');
      unawaited(_auditCall('signaling_connected'));
    } catch (_) {
      if (!mounted) return;
      unawaited(_auditCall('call_init_failed'));
      _showBanner('No se pudo iniciar la videollamada', Colors.redAccent,
          persistent: true, onRetry: _initCall);
    }
  }

  Future<bool> _ensureMediaPermissions() async {
    if (kIsWeb) return true;
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) return false;
    if (widget.audioOnly) return true;
    final cam = await Permission.camera.request();
    return cam.isGranted;
  }

  Future<void> _loadRemoteUserSummary() async {
    final remoteUid = widget.remoteUserId?.trim();
    if (remoteUid == null || remoteUid.isEmpty) return;

    String resolvedName = (_remoteDisplayName ?? '').trim();
    String orbitNumber = (_remoteOrbitNumber ?? '').trim();

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users_public')
          .doc(remoteUid)
          .get();
      final data = snap.data() ?? const <String, dynamic>{};
      resolvedName =
          ((data['fullName'] ?? data['displayName'] ?? resolvedName) as Object)
              .toString()
              .trim();
      orbitNumber =
          ((data['orbitNumber'] ?? orbitNumber) as Object).toString().trim();
    } catch (_) {
      // Se aplica fallback local abajo.
    }

    if (!mounted) return; // lifecycle safety fix

    final currentUid = _localUserId?.trim();
    if (currentUid != null && currentUid.isNotEmpty) {
      try {
        final localContact = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .collection('contacts')
            .doc(remoteUid)
            .get();
        final localData = localContact.data() ?? const <String, dynamic>{};
        if (resolvedName.isEmpty) {
          resolvedName =
              ((localData['fullName'] ?? '') as Object).toString().trim();
        }
        if (orbitNumber.isEmpty) {
          orbitNumber =
              ((localData['orbitNumber'] ?? '') as Object).toString().trim();
        }
      } catch (_) {
        // Si falla fallback local, conservamos valores previos.
      }
    }

    if (!mounted) return;
    setState(() {
      if (resolvedName.isNotEmpty) {
        _remoteDisplayName = resolvedName;
      }
      if (orbitNumber.isNotEmpty) {
        _remoteOrbitNumber = orbitNumber;
      }
      if (_remoteDisplayName == null || _remoteDisplayName!.trim().isEmpty) {
        _remoteDisplayName = 'Contacto Orbit';
      }
    });
  }

  String get _remoteTitle {
    final resolved = (_remoteDisplayName ?? '').trim();
    if (resolved.isNotEmpty) return resolved;
    final orbit = (_remoteOrbitNumber ?? '').trim();
    if (orbit.isNotEmpty) return 'OR-$orbit';
    return 'Contacto Orbit';
  }

  Future<void> _saveRemoteContact() async {
    final currentUid = _localUserId?.trim();
    final remoteUid = widget.remoteUserId?.trim();
    if (currentUid == null ||
        currentUid.isEmpty ||
        remoteUid == null ||
        remoteUid.isEmpty) {
      return;
    }

    if (currentUid == remoteUid) {
      _showBanner('No puedes agregarte a ti mismo', Colors.orangeAccent);
      return;
    }

    try {
      final remoteSnap = await FirebaseFirestore.instance
          .collection('users_public')
          .doc(remoteUid)
          .get();
      final data = remoteSnap.data() ?? const <String, dynamic>{};
      final contactName =
          ((data['fullName'] ?? data['displayName'] ?? _remoteTitle) as Object)
              .toString()
              .trim();
      final orbitNumber =
          ((data['orbitNumber'] ?? _remoteOrbitNumber ?? '') as Object)
              .toString()
              .trim();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('contacts')
          .doc(remoteUid)
          .set({
        'uid': remoteUid,
        'orbitNumber': orbitNumber,
        'fullName': contactName,
        'email': '',
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      _showBanner('Contacto guardado: $contactName', Colors.green);
    } catch (_) {
      if (!mounted) return;
      _showBanner('No se pudo guardar el contacto', Colors.redAccent);
    }
  }

  Future<void> _shareCallInvite() async {
    final remoteUid = (widget.remoteUserId ?? '').trim();
    final callType = widget.audioOnly ? 'voz' : 'video';
    final inviteLines = <String>[
      'InvitaciÃ³n a llamada Orbit',
      'Tipo: $callType',
      'Sala: $_roomId',
      if (_callSessionId != null && _callSessionId!.trim().isNotEmpty)
        'SesiÃ³n: ${_callSessionId!.trim()}',
      if (_remoteTitle.isNotEmpty) 'En llamada con: $_remoteTitle',
      if (remoteUid.isNotEmpty) 'UID remoto: $remoteUid',
      '',
      'Comparte estos datos solo con usuarios autorizados de Orbit.',
    ];

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: inviteLines.join('\n'),
          subject: 'InvitaciÃ³n a llamada Orbit',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _showBanner('No se pudo compartir la invitaciÃ³n', Colors.redAccent);
    }
  }

  Future<void> _connectSignalingWithRetry() async {
    int attempts = 0;
    const maxAttempts = 5;

    while (attempts < maxAttempts) {
      try {
        await _signaling.connect();
        return; // Ã‰xito
      } catch (e) {
        attempts++;
        if (attempts >= maxAttempts) {
          rethrow;
        }

        // Backoff exponencial: 500ms, 1s, 2s, 4s, 8s
        final delayMs = 500 * (1 << (attempts - 1));
        if (mounted) {
          _showBanner(
            'Reintentando conexiÃ³n... (intento $attempts/$maxAttempts)',
            Colors.orange,
          );
        }
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
  }

  Future<void> _startLocalStream() async {
    final profile = _adaptiveProfile;
    final mediaConstraints = {
      'audio': true,
      'video': widget.audioOnly
          ? false
          : {
              'facingMode': 'user',
              'width': profile.maxWidth,
              'height': profile.maxHeight,
              'frameRate': profile.maxFps,
            },
    };
    try {
      _logRtc('getUserMedia constraints=$mediaConstraints');
      _localStream =
          await navigator.mediaDevices.getUserMedia(mediaConstraints);
      unawaited(_auditCall('local_media_started'));
      _localRenderer.srcObject = _localStream;
      await _createPeerConnection();
      for (final track in _localStream!.getTracks()) {
        await _peerConnection?.addTrack(track, _localStream!);
        _logRtc('addTrack kind=${track.kind} enabled=${track.enabled}');
      }

      // Solo el iniciador envÃ­a oferta y la reintenta cuando el otro peer entra.
      if (_isCaller && _remotePeerJoined) {
        await _createAndSendOffer();
      }
    } catch (e) {
      _logRtc('error getUserMedia/addTrack: $e');
      unawaited(_auditCall('media_start_failed', extra: {'error': '$e'}));
      _showBanner('Error al iniciar cÃ¡mara/micrÃ³fono', Colors.redAccent,
          persistent: true, onRetry: _startLocalStream);
    }
  }

  Future<void> _createPeerConnection() async {
    // ========== PHASE 2: TURN/STUN CONFIGURATION ==========
    // Use TurnStunConfig to build ICE servers with fallbacks
    final iceServers = TurnStunConfig.buildIceServers(
      includeTestServers: !kReleaseMode,
    );

    final config = {
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
      'tcpCandidatePolicy': 'disabled',
      'continualGatheringPolicy': 'gather_once',
      'iceCandidatePoolSize': 0,
    };
    _logRtc('createPeerConnection iceServers=${iceServers.length}');
    _peerConnection = await createPeerConnection(config);
    if (!mounted) return; // lifecycle safety fix
    if (mounted) {
      setState(() {
        _iceStatus = _shortEnumValue(_peerConnection!.iceConnectionState);
        _pcStatus = _shortEnumValue(_peerConnection!.connectionState);
        _signalStatus = _shortEnumValue(_peerConnection!.signalingState);
      });
    }
    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (!mounted) return; // lifecycle safety fix
      if (event.streams.isNotEmpty) {
        _logRtc(
            'onTrack kind=${event.track.kind} streams=${event.streams.length}');
        setState(() {
          _remoteRenderer.srcObject = event.streams[0];
        });
      }
    };
    _peerConnection?.onIceCandidate = (candidate) {
      if (candidate.candidate == null || candidate.candidate!.isEmpty) {
        _logRtc('onIceCandidate end-of-candidates');
        return;
      }
      final pathType = _candidatePathType(candidate.candidate);
      if (mounted) {
        setState(() {
          if (pathType.isNotEmpty) {
            _localPathType = pathType;
          }
          _localCandidateCount++;
        });
      }
      _logRtc(
          'onIceCandidate local #$_localCandidateCount type=$pathType mid=${candidate.sdpMid} line=${candidate.sdpMLineIndex}');
      _signaling.send({
        'type': 'candidate',
        'candidate': candidate.toMap(),
      }).catchError((_) {});
    };

    // â”€â”€ ICE connection state: detecta cortes y lanza ICE restart automÃ¡tico â”€â”€
    _peerConnection?.onIceConnectionState = (RTCIceConnectionState state) {
      if (!mounted) return;
      _logRtc('iceConnectionState=${_shortEnumValue(state)}');
      setState(() => _iceStatus = _shortEnumValue(state));
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          if (_connectionEstablishedOnce) {
            setState(() {
              _callRealtimeState = RealtimeUxState.reconnecting;
              _callRealtimeMessage = 'Conexión inestable. Reconectando...';
            });
            _showBanner('Conexión inestable, reconectando...', Colors.orange);
          }
          _requestIceRecovery(
            reason: 'ice_disconnected',
            trigger: 'ice_state_disconnected',
          );
          break;
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          if (_connectionEstablishedOnce) {
            setState(() {
              _callRealtimeState = RealtimeUxState.reconnecting;
              _callRealtimeMessage = 'Conexión perdida. Reiniciando enlace...';
            });
          }
          unawaited(_auditCall('ice_failed'));
          if (_connectionEstablishedOnce) {
            _showBanner('Conexión perdida, reiniciando ICE...', Colors.orange);
          }
          _requestIceRecovery(
            reason: 'ice_failed',
            trigger: 'ice_state_failed',
          );
          break;
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          _connectionEstablishedOnce = true;
          setState(() {
            _callRealtimeState = RealtimeUxState.online;
            _callRealtimeMessage = 'Llamada conectada';
          });
          _markIceRecovered();
          _connectTimeoutTimer?.cancel();
          unawaited(_auditCall('ice_connected'));
          _startCallTimerIfNeeded();
          if (mounted) _showBanner('Conectado', Colors.green);
          break;
        case RTCIceConnectionState.RTCIceConnectionStateClosed:
          _cancelIceRestartTimer();
          _iceRecoveryTimeoutTimer?.cancel();
          break;
        default:
          break;
      }
    };

    // â”€â”€ Connection state: segunda lÃ­nea de defensa â”€â”€
    _peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
      if (!mounted) return;
      _logRtc('connectionState=${_shortEnumValue(state)}');
      setState(() => _pcStatus = _shortEnumValue(state));
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _connectionEstablishedOnce = true;
        setState(() {
          _callRealtimeState = RealtimeUxState.online;
          _callRealtimeMessage = 'Llamada estable';
        });
        _connectTimeoutTimer?.cancel();
        _markIceRecovered();
        unawaited(_auditCall('peer_connected'));
        _startCallTimerIfNeeded();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        if (_connectionEstablishedOnce) {
          setState(() {
            _callRealtimeState = RealtimeUxState.reconnecting;
            _callRealtimeMessage =
                'Error de conexión. Intentando recuperar llamada...';
          });
        }
        unawaited(_auditCall('peer_failed'));
        _requestIceRecovery(
          reason: 'pc_failed',
          trigger: 'pc_state_failed',
        );
      }
    };

    _peerConnection?.onSignalingState = (RTCSignalingState state) {
      if (!mounted) return;
      _logRtc('signalingState=${_shortEnumValue(state)}');
      setState(() => _signalStatus = _shortEnumValue(state));
    };
    _startIceHeartbeat();
  }

  void _startCallTimerIfNeeded() {
    if (_stopwatch.isRunning) return;
    _stopOutgoingRingtone();
    _stopwatch.start();
    if (mounted) {
      setState(() {
        _callDuration = '00:00';
      });
    }
  }

  void _requestIceRecovery({
    required String reason,
    required String trigger,
    bool remoteRequest = false,
  }) {
    final now = DateTime.now();
    if (!_consumeStormBudget(now)) {
      _logRtc(
          'ðŸ›¡ï¸ storm protection activated; trigger=$trigger reason=$reason');
      _showBanner(
        'ProtecciÃ³n anti-tormenta activa, estabilizando reconexiÃ³n...',
        Colors.orange,
      );
      return;
    }

    if (!remoteRequest) {
      final last = _lastRecoveryTriggerAt;
      if (last != null && now.difference(last).inMilliseconds < 1200) {
        _logRtc('skip duplicate recovery trigger=$trigger reason=$reason');
        return;
      }
    }

    _lastRecoveryTriggerAt = now;
    _iceRecoveryInProgress = true;
    _armIceRecoveryTimeout(reason: reason, remoteRequest: remoteRequest);

    if (!_isCaller && !remoteRequest) {
      unawaited(_sendRestartIceSignal(reason: reason, trigger: trigger));
      _logRtc(
          'callee requested remote ICE restart first (reason=$reason trigger=$trigger)');
      return;
    }

    _scheduleIceRestart(remoteRequest: remoteRequest, reason: reason);
  }

  void _scheduleIceRestart({
    required bool remoteRequest,
    required String reason,
  }) {
    if (_iceReconnectAttempts >= _maxIceReconnectAttempts) {
      _logRtc(
          'âš ï¸ ICE reconnect max attempts ($_iceReconnectAttempts/$_maxIceReconnectAttempts) reached.');
      _showBanner(
        'ConexiÃ³n perdida permanentemente. Terminar llamada.',
        Colors.red,
        persistent: true,
      );
      return;
    }

    _iceRestartTimer?.cancel();
    final baseDelayMs = (_minIceReconnectDelayMs * (1 << _iceReconnectAttempts))
        .clamp(_minIceReconnectDelayMs, _maxIceReconnectDelayMs);
    final jitterFactor = 0.75 + (_random.nextDouble() * 0.5);
    final finalDelayMs = (baseDelayMs * jitterFactor).round();
    _logRtc(
        'â±ï¸ ICE reconnect attempt ${_iceReconnectAttempts + 1}/$_maxIceReconnectAttempts in ${finalDelayMs}ms (base=${baseDelayMs}ms jitter=${jitterFactor.toStringAsFixed(2)} reason=$reason remoteRequest=$remoteRequest)');

    _iceRestartTimer = Timer(Duration(milliseconds: finalDelayMs), () {
      _iceReconnectAttempts++;
      unawaited(
        _doIceRestart(
          remoteRequest: remoteRequest,
          reason: reason,
        ),
      );
    });
  }

  void _cancelIceRestartTimer() {
    _iceRestartTimer?.cancel();
    _iceRestartTimer = null;
  }

  void _markIceRecovered() {
    _cancelIceRestartTimer();
    _iceRecoveryTimeoutTimer?.cancel();
    _iceRecoveryInProgress = false;
    _iceReconnectAttempts = 0;
    _heartbeatUnhealthyTicks = 0;
  }

  void _armIceRecoveryTimeout({
    required String reason,
    required bool remoteRequest,
  }) {
    _iceRecoveryTimeoutTimer?.cancel();
    _iceRecoveryTimeoutTimer = Timer(_iceRecoveryTimeout, () {
      if (!mounted) return;
      final iceState = _peerConnection?.iceConnectionState;
      final healthy =
          iceState == RTCIceConnectionState.RTCIceConnectionStateConnected ||
              iceState == RTCIceConnectionState.RTCIceConnectionStateCompleted;
      if (healthy) return;

      _logRtc(
          'â±ï¸ ICE recovery timeout reason=$reason remoteRequest=$remoteRequest');
      _showBanner('Reintento inteligente de conexiÃ³n...', Colors.orange);
      if (!_isCaller && !remoteRequest) {
        // EscalaciÃ³n: si el caller no reaccionÃ³ al restartIce, el callee tambiÃ©n
        // puede forzar ICE restart para recuperar la llamada.
        _scheduleIceRestart(remoteRequest: true, reason: 'timeout_escalation');
        return;
      }
      _scheduleIceRestart(
        remoteRequest: remoteRequest,
        reason: 'timeout_retry',
      );
    });
  }

  void _startIceHeartbeat() {
    _iceHeartbeatTimer?.cancel();
    _iceHeartbeatTimer = Timer.periodic(_iceHeartbeatInterval, (_) {
      if (!mounted || _peerConnection == null) return;
      final iceState = _peerConnection!.iceConnectionState;
      final healthy =
          iceState == RTCIceConnectionState.RTCIceConnectionStateConnected ||
              iceState == RTCIceConnectionState.RTCIceConnectionStateCompleted;
      if (healthy) {
        if (_heartbeatUnhealthyTicks > 0) {
          _logRtc(
              'heartbeat: ICE recovered state=${_shortEnumValue(iceState)}');
        }
        _heartbeatUnhealthyTicks = 0;
        return;
      }

      _heartbeatUnhealthyTicks++;
      _logRtc(
          'heartbeat: unhealthy tick=$_heartbeatUnhealthyTicks state=${_shortEnumValue(iceState)} inProgress=$_iceRecoveryInProgress');
      if (_heartbeatUnhealthyTicks >= _heartbeatUnhealthyThreshold &&
          !_iceRecoveryInProgress) {
        _requestIceRecovery(
          reason: 'heartbeat_unhealthy',
          trigger: 'heartbeat',
        );
      }
    });
  }

  bool _consumeStormBudget(DateTime now) {
    if (now.difference(_restartStormWindowStart) > const Duration(minutes: 1)) {
      _restartStormWindowStart = now;
      _restartStormCount = 0;
    }
    if (_restartStormCount >= _maxReconnectStormPerMinute) {
      return false;
    }
    _restartStormCount++;
    return true;
  }

  Future<void> _sendRestartIceSignal({
    required String reason,
    required String trigger,
  }) async {
    final now = DateTime.now();
    final last = _lastRestartSignalAt;
    if (last != null && now.difference(last) < _restartSignalCooldown) {
      _logRtc(
          'restartIce signal cooldown active; trigger=$trigger reason=$reason');
      return;
    }
    _lastRestartSignalAt = now;
    final requestId =
        '${_isCaller ? 'caller' : 'callee'}_${now.microsecondsSinceEpoch}_${_random.nextInt(1 << 20)}';
    _handledRestartRequestIds.add(requestId);
    _logRtc(
        'ðŸ“¡ send restartIce requestId=$requestId trigger=$trigger reason=$reason');
    await _signaling.send({
      'type': 'restartIce',
      'requestId': requestId,
      'from': _localUserId,
      'reason': reason,
    });
  }

  Future<void> _doIceRestart({
    bool remoteRequest = false,
    required String reason,
  }) async {
    _cancelIceRestartTimer();
    if (_peerConnection == null) {
      _logRtc('âš ï¸ ICE restart skipped: no peer connection');
      return;
    }
    // Si es callee y no es remoteRequest, seÃ±aliza al peer para que reinicie
    if (!_isCaller && !remoteRequest) {
      await _sendRestartIceSignal(
        reason: reason,
        trigger: 'do_ice_restart_callee',
      );
      return;
    }
    try {
      _logRtc(
          'ðŸ”„ ICE restart attempt $_iceReconnectAttempts/$_maxIceReconnectAttempts: createOffer (isCaller=$_isCaller, remoteRequest=$remoteRequest, reason=$reason)');
      final offer = await _peerConnection!.createOffer({'iceRestart': true});
      if (offer.sdp == null || offer.sdp!.isEmpty) {
        throw Exception('Invalid offer SDP');
      }
      final optimizedSdp = WebRTCService.optimizeSdpForMobileEfficiency(
        offer.sdp!,
        maxVideoBitrateKbps: _adaptiveProfile.targetBitrateKbps,
        preferH264: true,
      );
      final optimizedOffer = RTCSessionDescription(optimizedSdp, 'offer');
      await _peerConnection!.setLocalDescription(optimizedOffer);
      _logRtc('âœ… ICE restart localDescription set');
      await _signaling.send({
        'type': 'offer',
        'sdp': optimizedSdp,
      }).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Signaling send timeout'),
      );
      _logRtc('âœ… ICE restart offer sent');
    } on TimeoutException catch (_) {
      _logRtc('â±ï¸ ICE restart timeout, scheduling retry...');
      _showBanner('Reintentando conexiÃ³n (timeout)...', Colors.orange);
      if (_iceReconnectAttempts < _maxIceReconnectAttempts) {
        _scheduleIceRestart(
          remoteRequest: remoteRequest,
          reason: 'send_timeout',
        );
      }
    } catch (e) {
      _logRtc('âŒ ICE restart failed: $e');
      _showBanner(
          'No se pudo reiniciar la conexiÃ³n, reintentando...', Colors.orange);
      if (_iceReconnectAttempts < _maxIceReconnectAttempts) {
        _scheduleIceRestart(
          remoteRequest: remoteRequest,
          reason: 'restart_failed',
        );
      } else {
        _showBanner('ConexiÃ³n perdida permanentemente', Colors.red,
            persistent: true);
      }
    }
  }

  Future<void> _createAndSendOffer() async {
    if (!_isCaller || _offerSent) return;
    _offerSent = true;
    if (_peerConnection == null) await _createPeerConnection();
    _logRtc('createOffer');
    final offer = await _peerConnection?.createOffer();
    if (offer == null) return;
    final rawSdp = offer.sdp;
    if (rawSdp == null || rawSdp.isEmpty) return;
    final optimizedSdp = WebRTCService.optimizeSdpForMobileEfficiency(
      rawSdp,
      maxVideoBitrateKbps: _adaptiveProfile.targetBitrateKbps,
      preferH264: true,
    );
    final optimizedOffer = RTCSessionDescription(optimizedSdp, 'offer');
    await _peerConnection?.setLocalDescription(optimizedOffer);
    _logRtc(
        'setLocalDescription offer ok sdpLen=${optimizedSdp.length} bitrate=${_adaptiveProfile.targetBitrateKbps}kbps res=${_adaptiveProfile.maxWidth}x${_adaptiveProfile.maxHeight} fps=${_adaptiveProfile.maxFps}');
    await _signaling.send({
      'type': 'offer',
      'sdp': optimizedSdp,
      if (widget.remoteUserId != null) 'to': widget.remoteUserId,
      if (_localUserId != null) 'from': _localUserId,
    });
    _logRtc('offer enviado');
    unawaited(_auditCall('offer_sent'));
  }

  void _handleSignalingMessage(Map<String, dynamic> msg) async {
    if (!mounted) return; // lifecycle safety fix
    switch (msg['type']) {
      case 'joined':
      case 'peer-joined':
        _logRtc('peer-joined recibido');
        _remotePeerJoined = true;
        if (_isCaller && _localStream != null) {
          await _createAndSendOffer();
        }
        break;
      case 'offer':
        _logRtc(
            'offer recibido sdpLen=${(msg['sdp'] ?? '').toString().length}');
        if (_peerConnection == null) await _createPeerConnection();
        await _peerConnection
            ?.setRemoteDescription(RTCSessionDescription(msg['sdp'], 'offer'));
        _remoteDescriptionSet = true;
        await _flushPendingRemoteCandidates();
        _logRtc('setRemoteDescription offer ok');
        final answer = await _peerConnection?.createAnswer();
        if (answer != null) {
          final rawSdp = answer.sdp;
          if (rawSdp == null || rawSdp.isEmpty) break;
          final optimizedSdp = WebRTCService.optimizeSdpForMobileEfficiency(
            rawSdp,
            maxVideoBitrateKbps: _adaptiveProfile.targetBitrateKbps,
            preferH264: true,
          );
          final optimizedAnswer = RTCSessionDescription(optimizedSdp, 'answer');
          await _peerConnection?.setLocalDescription(optimizedAnswer);
          _logRtc(
              'setLocalDescription answer ok sdpLen=${optimizedSdp.length} bitrate=${_adaptiveProfile.targetBitrateKbps}kbps res=${_adaptiveProfile.maxWidth}x${_adaptiveProfile.maxHeight} fps=${_adaptiveProfile.maxFps}');
          await _signaling.send({
            'type': 'answer',
            'sdp': optimizedSdp,
            if (widget.remoteUserId != null) 'to': widget.remoteUserId,
            if (_localUserId != null) 'from': _localUserId,
          });
          _logRtc('answer enviado');
          unawaited(_auditCall('answer_sent'));
        }
        break;
      case 'answer':
        _logRtc(
            'answer recibido sdpLen=${(msg['sdp'] ?? '').toString().length}');
        await _peerConnection
            ?.setRemoteDescription(RTCSessionDescription(msg['sdp'], 'answer'));
        _remoteDescriptionSet = true;
        await _flushPendingRemoteCandidates();
        _logRtc('setRemoteDescription answer ok');
        unawaited(_auditCall('answer_received'));
        break;
      case 'candidate':
        final cand = msg['candidate'];
        if (cand is! Map) {
          _logRtc('candidate invÃ¡lido ignorado');
          return;
        }
        final candidateValue = (cand['candidate'] ?? '').toString();
        if (candidateValue.isEmpty) {
          _logRtc('candidate vacÃ­o ignorado');
          return;
        }
        final remoteCandidate = (cand['candidate'] ?? '').toString();
        final remotePathType = _candidatePathType(remoteCandidate);
        if (mounted) {
          setState(() {
            if (remotePathType.isNotEmpty) {
              _remotePathType = remotePathType;
            }
            _remoteCandidateCount++;
          });
        }
        final sdpMid = cand['sdpMid']?.toString();
        final lineIndexRaw = cand['sdpMLineIndex'];
        final sdpMLineIndex = lineIndexRaw is num
            ? lineIndexRaw.toInt()
            : int.tryParse('$lineIndexRaw');
        final rtcCandidate = RTCIceCandidate(
          candidateValue,
          sdpMid,
          sdpMLineIndex,
        );
        _logRtc(
            'candidate remoto #$_remoteCandidateCount type=$remotePathType mid=$sdpMid line=$sdpMLineIndex');
        await _addOrBufferRemoteCandidate(rtcCandidate);
        break;
      case 'restartIce':
        final requestId = (msg['requestId'] as String?)?.trim();
        if (requestId != null && requestId.isNotEmpty) {
          if (_handledRestartRequestIds.contains(requestId)) {
            _logRtc('restartIce duplicado ignorado requestId=$requestId');
            return;
          }
          _handledRestartRequestIds.add(requestId);
        }
        final reason = (msg['reason'] as String?)?.trim() ?? 'remote_request';
        final from = (msg['from'] as String?)?.trim();
        _logRtc(
            'restartIce recibido requestId=$requestId from=$from reason=$reason');
        _requestIceRecovery(
          reason: reason,
          trigger: 'remote_restart_signal',
          remoteRequest: true,
        );
        break;
    }
  }

  Future<void> _addOrBufferRemoteCandidate(RTCIceCandidate candidate) async {
    if (_peerConnection == null || !_remoteDescriptionSet) {
      // STABILIZATION: Limit ICE buffer to prevent memory exhaustion
      if (_pendingRemoteCandidates.length >= _maxPendingIceCandidates) {
        _logRtc(
            'âš ï¸ ICE buffer FULL (${_pendingRemoteCandidates.length}/$_maxPendingIceCandidates). Dropping oldest candidate.');
        _pendingRemoteCandidates.removeAt(0); // Remove oldest (FIFO drop)
      }
      _pendingRemoteCandidates.add(candidate);
      _logRtc(
          'candidate remoto en buffer (total=${_pendingRemoteCandidates.length}/$_maxPendingIceCandidates)');
      return;
    }

    try {
      await _peerConnection!.addCandidate(candidate);
      _logRtc('addCandidate remoto aplicado');
    } catch (e) {
      _logRtc('error addCandidate remoto: $e');
    }
  }

  Future<void> _flushPendingRemoteCandidates() async {
    if (_peerConnection == null || !_remoteDescriptionSet) return;
    if (_pendingRemoteCandidates.isEmpty) return;

    final buffered = List<RTCIceCandidate>.from(_pendingRemoteCandidates);
    _pendingRemoteCandidates.clear();
    _logRtc('flush ${buffered.length} candidatos remotos pendientes');

    for (final cand in buffered) {
      try {
        await _peerConnection!.addCandidate(cand);
      } catch (e) {
        _logRtc('error addCandidate buffered: $e');
      }
    }
  }

  void _logRtc(String message) {
    debugPrint('[WebRTC][room=$_roomId][caller=$_isCaller] $message');
  }

  Future<void> _auditCall(String eventType,
      {Map<String, Object?> extra = const <String, Object?>{}}) async {
    try {
      await CallDiagnosticsService.logEvent(
        eventType: eventType,
        callSessionId: _callSessionId,
        roomId: _roomId,
        peerUserId: widget.remoteUserId,
        extra: {
          'isCaller': _isCaller,
          'audioOnly': widget.audioOnly,
          'sessionStatus': _sessionStatus,
          'iceStatus': _iceStatus,
          'pcStatus': _pcStatus,
          'signalStatus': _signalStatus,
          'localCandidates': _localCandidateCount,
          'remoteCandidates': _remoteCandidateCount,
          'adaptiveTier': _adaptiveProfile.pauseVideo
              ? 'critical'
              : (_adaptiveProfile.batterySaver ? 'saver' : 'high'),
          'adaptiveWidth': _adaptiveProfile.maxWidth,
          'adaptiveHeight': _adaptiveProfile.maxHeight,
          'adaptiveFps': _adaptiveProfile.maxFps,
          'adaptiveTargetBitrateKbps': _adaptiveProfile.targetBitrateKbps,
          'adaptiveMinBitrateKbps': _adaptiveProfile.minBitrateKbps,
          'adaptivePauseVideo': _adaptiveProfile.pauseVideo,
          'adaptiveBatterySaver': _adaptiveProfile.batterySaver,
          'adaptiveThermalLevel': _adaptiveProfile.thermalLevel.name,
          'thermalLevelUi': _thermalLevel.name,
          'batterySaverModeUi': _batterySaverMode,
          ...extra,
        },
      );
    } catch (e) {
      debugPrint('[WebRTC][audit] $e');
    }
  }

  Future<void> _cleanupSignalingRoomIfNeeded() async {
    if (_roomCleanupStarted) return;
    _roomCleanupStarted = true;
    try {
      await _signaling.cleanupRoom();
      await _auditCall('signaling_room_cleaned');
    } catch (e) {
      _roomCleanupStarted = false;
      debugPrint('[WebRTC][cleanup] $e');
    }
  }

  Future<void> _acceptIncomingSessionIfNeeded(String callId) async {
    if (_isCaller || _incomingSessionAcceptRequested) return;
    _incomingSessionAcceptRequested = true;
    try {
      await CallSessionService.acceptSession(callId);
      if (!mounted) return;
      FCMService.markIncomingCallSessionActive(callId);
    } catch (e) {
      _incomingSessionAcceptRequested = false;
      _logRtc('incoming accept failed: $e');
    }
  }

  String _shortEnumValue(Object? value) {
    if (value == null) return 'n/d';
    final raw = value.toString();
    final idx = raw.lastIndexOf('.');
    return idx == -1 ? raw : raw.substring(idx + 1);
  }

  String _candidatePathType(String? candidate) {
    final c = (candidate ?? '').toLowerCase();
    if (c.contains(' typ relay')) return 'relay';
    if (c.contains(' typ srflx')) return 'srflx';
    if (c.contains(' typ host')) return 'host';
    return '';
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

  Future<void> _configureAudioRouting() async {
    try {
      await Helper.setSpeakerphoneOn(speakerOn);
    } catch (_) {}
  }

  void _toggleSpeaker() {
    // flutter_webrtc maneja el altavoz en dispositivos mÃ³viles con setSpeakerphoneOn
    unawaited(_configureAudioRouting());
  }

  void _showBanner(String message, Color color,
      {bool persistent = false, VoidCallback? onRetry}) {
    if (!mounted) return; // lifecycle safety fix
    final state = color == Colors.green
        ? RealtimeUxState.online
        : (color == Colors.red || color == Colors.redAccent)
            ? RealtimeUxState.error
            : (color == Colors.orange || color == Colors.orangeAccent)
                ? RealtimeUxState.reconnecting
                : RealtimeUxState.queued;
    setState(() {
      _callRealtimeState = state;
      _callRealtimeMessage = message;
    });
    ErrorPresenter.showSnack(
      context,
      message,
      state: state,
      actionLabel: onRetry != null ? 'Reintentar' : null,
      onAction: onRetry,
      duration:
          persistent ? const Duration(seconds: 6) : const Duration(seconds: 3),
    );
  }

  bool micOn = true;
  bool speakerOn = false;
  bool cameraOn = true;

  @override
  Widget build(BuildContext context) {
    final hasRemoteVideo = _videoEnabled && !widget.audioOnly;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
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
                      'Conectando con $_remoteTitle',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  if (_peerConnection != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Semantics(
                        label: 'DuraciÃ³n de la llamada',
                        child: Text(
                            _stopwatch.isRunning
                                ? 'â± $_callDuration'
                                : (_isCaller
                                    ? 'Llamando...'
                                    : 'Esperando conexiÃ³n...'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  // BotÃ³n para alternar video
                  Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: IconButton(
                      icon: Icon(
                          _videoEnabled ? Icons.videocam : Icons.videocam_off,
                          color: Colors.white,
                          size: 36),
                      onPressed: _toggleVideo,
                      tooltip:
                          _videoEnabled ? 'Desactivar video' : 'Activar video',
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ...resto de la UI (barras, controles, etc.)
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
                  color: Colors.white.withAlpha(232),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD8E3EF)),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _remoteTitle,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF16324F),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${ErrorPresenter.stateLabel(_callRealtimeState)} · $_callRealtimeMessage · ${_networkQuality.name} · $_localPathType/$_remotePathType',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF56728E),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_videoDegraded)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(24),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: const Text(
                          'Video degradado',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    Text(
                      _stopwatch.isRunning
                          ? _callDuration
                          : (_isCaller ? 'Timbrando' : 'Conectando'),
                      style: const TextStyle(color: Color(0xFF6D7F92)),
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
                  border: Border.all(color: Colors.white),
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
                    color: Colors.white.withAlpha(232),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD8E3EF)),
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
                                ? 'MicrÃ³fono activado'
                                : 'MicrÃ³fono desactivado',
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => micOn = !micOn);
                              _showBanner(
                                  micOn
                                      ? 'MicrÃ³fono activado'
                                      : 'MicrÃ³fono desactivado',
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
                                  ? 'CÃ¡mara activada'
                                  : 'CÃ¡mara desactivada',
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => cameraOn = !cameraOn);
                                _showBanner(
                                    cameraOn
                                        ? 'CÃ¡mara activada'
                                        : 'CÃ¡mara desactivada',
                                    cameraOn ? Colors.green : Colors.red);
                                _toggleCamera();
                              },
                            ),
                          _controlButton(
                            icon: speakerOn
                                ? Icons.speaker_phone
                                : Icons.speaker_phone_outlined,
                            color: speakerOn ? Colors.white : Colors.red,
                            label: 'Altavoz',
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
                              color: const Color(0xFF6D7F92),
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
                                label: 'Contacto',
                                semanticLabel: 'Guardar contacto',
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  unawaited(_saveRemoteContact());
                                },
                              ),
                              _controlButton(
                                icon: Icons.link,
                                color: Colors.white,
                                label: 'Invitar',
                                semanticLabel:
                                    'Compartir invitaciÃ³n de llamada',
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  unawaited(_shareCallInvite());
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
                                      : '$_latencyMs ms',
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
    String? label,
  }) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FB),
              shape: BoxShape.circle,
            ),
            child: CameraIconButton(
              icon: icon,
              tooltip: semanticLabel ?? '',
              onTap: onTap,
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6D7F92),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
