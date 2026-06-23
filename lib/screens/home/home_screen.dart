import 'package:flutter/material.dart';
import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Home tabs
import 'history_screen.dart';
import 'settings_screen.dart';
import 'status_screen.dart';

// Communication
import '../communication/call_screen.dart';
import '../communication/chat_screen.dart' as chat;
import '../communication/chat_hub_screen.dart';
import '../communication/video_call_screen.dart';

// Services
import '../../services/auth_service.dart';
import '../../services/call_session_service.dart';
import '../../services/network_service.dart';
import '../../services/resilient_stream_helper.dart';
import '../../utils/error_presenter.dart';

// Orbit IA
import '../ia/orbit_ia_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _displayName = 'Usuario ORBIT';
  String _networkLabel = 'Analizando red...';
  Color _networkColor = const Color(0xFF8AA4BF);
  int? _latencyMs;
  String _recommendedMode = 'chat';
  bool _isSatellite = false;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _incomingCallSub;
  ResilientStreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _incomingCallResilient;
  String? _activeIncomingCallId;
  String? _incomingCallerId;
  String? _incomingCallerName;
  bool _incomingAudioOnly = true;
  String _incomingListenerStatusLabel = '';
  RealtimeUxState _homeRealtimeState = RealtimeUxState.reconnecting;
  String _homeRealtimeMessage = 'Conectando servicios en tiempo real...';

  Timer? _networkTimer;
  final AudioPlayer _incomingRingPlayer = AudioPlayer();
  bool _incomingRingtonePlaying = false;

  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    _loadUserDisplay();
    _refreshNetworkInsight();
    _listenForIncomingCalls();
    _ensureOrbitNumberPresent();
    _networkTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshNetworkInsight(),
    );
  }

  /// Reintenta asignar el número Orbit si no quedó durante el registro
  /// (puede ocurrir cuando App Check falla transitoriamente en el primer intento).
  Future<void> _ensureOrbitNumberPresent() async {
    try {
      await AuthService.ensureCurrentUserProvisioned();
    } catch (e) {
      debugPrint('ensureOrbitNumber en home: $e');
    }
  }

  @override
  void dispose() {
    _networkTimer?.cancel();
    unawaited(_incomingCallResilient?.cancel());
    _incomingCallSub?.cancel();
    unawaited(_stopIncomingRingtone());
    unawaited(_incomingRingPlayer.dispose());
    super.dispose();
  }

  Future<void> _loadUserDisplay() async {
    final user = AuthService.getCurrentUser();
    if (!mounted) return;

    // Prioridad: displayName de Auth → fullName de Firestore → uid → default
    String name = user?.displayName?.trim() ?? '';
    if (name.isEmpty && user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        name = (doc.data()?['fullName'] as String?)?.trim() ?? '';
      } catch (_) {}
    }
    if (name.isEmpty) name = user?.email?.split('@').first ?? 'Usuario ORBIT';

    if (!mounted) return;
    setState(() => _displayName = name);
  }

  Future<void> _refreshNetworkInsight() async {
    final service = NetworkService();
    final qualityEnum = await service.getNetworkQuality();
    final latency = await service.measureLatencyMs();
    final isSatellite = await service.isSatelliteConnected();

    final quality = qualityEnum.name;
    final insight = _buildNetworkInsight(quality, latency);

    if (!mounted) return;
    setState(() {
      _networkLabel = insight.label;
      _networkColor = insight.color;
      _recommendedMode = insight.recommendedMode;
      _latencyMs = latency;
      _isSatellite = isSatellite;
      _homeRealtimeState =
          quality == 'none' ? RealtimeUxState.offline : RealtimeUxState.online;
      _homeRealtimeMessage = quality == 'none'
          ? 'Sin internet. Funciones limitadas hasta reconectar.'
          : 'En línea. Realtime activo.';
    });
  }

  _NetworkInsight _buildNetworkInsight(String quality, int? latencyMs) {
    if (quality == 'none') {
      return const _NetworkInsight(
        label: 'Sin conexión',
        color: Color(0xFFE15759),
        recommendedMode: 'chat',
      );
    }
    if (quality == 'low') {
      return const _NetworkInsight(
        label: 'Señal inestable',
        color: Color(0xFFF28E2B),
        recommendedMode: 'chat',
      );
    }
    if (quality == 'medium') {
      if (latencyMs != null && latencyMs > 240) {
        return const _NetworkInsight(
          label: 'Señal media, latencia alta',
          color: Color(0xFFF1C453),
          recommendedMode: 'chat',
        );
      }
      return const _NetworkInsight(
        label: 'Señal media',
        color: Color(0xFFE0C15A),
        recommendedMode: 'voz o chat',
      );
    }
    if (latencyMs != null && latencyMs > 200) {
      return const _NetworkInsight(
        label: 'Señal alta, latencia variable',
        color: Color(0xFF63D5A8),
        recommendedMode: 'llamada de voz',
      );
    }
    return const _NetworkInsight(
      label: 'Señal óptima',
      color: Color(0xFF4ECCA3),
      recommendedMode: 'todos los servicios',
    );
  }

  void _listenForIncomingCalls() {
    final uid = AuthService.getCurrentUser()?.uid;
    if (uid == null) return;

    unawaited(_incomingCallResilient?.cancel());
    _incomingCallSub?.cancel();

    _incomingCallResilient =
        ResilientStreamSubscription<QuerySnapshot<Map<String, dynamic>>>(
      streamFactory: () => CallSessionService.incomingRingingStream(),
      timeout: const Duration(seconds: 15),
      logTag: 'HomeIncomingCallStream:$uid',
      onStatus: (status) {
        _applyIncomingCallListenerStatus(status);
      },
      onError: (error, _) {
        debugPrint('[HomeIncomingCallStream:$uid] error=$error');
      },
      onData: (snap) {
        if (snap.docs.isEmpty) {
          unawaited(_stopIncomingRingtone());
          if (!mounted) return;
          setState(() {
            _activeIncomingCallId = null;
            _incomingCallerId = null;
            _incomingCallerName = null;
            _incomingAudioOnly = true;
          });
          return;
        }

        final callDoc = snap.docs.first;
        final session = callDoc.data();
        final status = session['status'] as String?;
        final expiresAt = session['ringingExpiresAt'] as Timestamp?;
        final nowTs = Timestamp.now();

        if (expiresAt != null && expiresAt.compareTo(nowTs) <= 0) {
          unawaited(
            callDoc.reference.update({
              'status': 'missed',
              'endedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }).catchError((_) {}),
          );
          unawaited(_stopIncomingRingtone());
          if (!mounted) return;
          setState(() {
            _activeIncomingCallId = null;
            _incomingCallerId = null;
            _incomingCallerName = null;
            _incomingAudioOnly = true;
          });
          return;
        }

        if (status == 'ringing' && _activeIncomingCallId != callDoc.id) {
          final callType =
              (session['callType'] as String?)?.trim().toLowerCase();
          if (!mounted) return;
          setState(() {
            _activeIncomingCallId = callDoc.id;
            _incomingCallerId = session['callerId'] as String?;
            _incomingAudioOnly = callType != 'video';
          });
          unawaited(_startIncomingRingtone());
          _fetchCallerName(_incomingCallerId);
        } else if (status == 'accepted' ||
            status == 'ended' ||
            status == 'missed' ||
            status == 'rejected') {
          unawaited(_stopIncomingRingtone());
          if (!mounted) return;
          setState(() {
            _activeIncomingCallId = null;
            _incomingCallerId = null;
            _incomingCallerName = null;
            _incomingAudioOnly = true;
          });
        }
      },
    );
    _incomingCallResilient!.start();
  }

  void _applyIncomingCallListenerStatus(ResilientStreamStatus status) {
    if (!mounted) return;
    final prevState = _homeRealtimeState;
    final prevMessage = _homeRealtimeMessage;
    String label;
    switch (status) {
      case ResilientStreamStatus.connected:
        label = '';
        _homeRealtimeState = RealtimeUxState.online;
        _homeRealtimeMessage = 'Sincronización en tiempo real activa.';
        break;
      case ResilientStreamStatus.connecting:
      case ResilientStreamStatus.reconnecting:
        label = 'Reconectando...';
        _homeRealtimeState = RealtimeUxState.reconnecting;
        _homeRealtimeMessage = 'Reconectando eventos en tiempo real...';
        break;
      case ResilientStreamStatus.timeout:
      case ResilientStreamStatus.offline:
        label = 'Sin conexión';
        _homeRealtimeState = status == ResilientStreamStatus.timeout
            ? RealtimeUxState.timeout
            : RealtimeUxState.offline;
        _homeRealtimeMessage = status == ResilientStreamStatus.timeout
            ? 'Timeout de red. Reintentando suscripción...'
            : 'Sin conexión para eventos en tiempo real.';
        break;
    }
    if (_incomingListenerStatusLabel != label ||
        prevState != _homeRealtimeState ||
        prevMessage != _homeRealtimeMessage) {
      setState(() {
        _incomingListenerStatusLabel = label;
      });
    }
  }

  Future<void> _startIncomingRingtone() async {
    if (_incomingRingtonePlaying) return;
    _incomingRingtonePlaying = true;
    try {
      await _incomingRingPlayer.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            audioMode: AndroidAudioMode.normal,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransient,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {AVAudioSessionOptions.mixWithOthers},
          ),
        ),
      );
      await _incomingRingPlayer.setReleaseMode(ReleaseMode.loop);
      await _incomingRingPlayer.setVolume(1.0);
      await _incomingRingPlayer.play(AssetSource('audio/outgoing_ring.wav'));
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
      await _incomingRingPlayer.stop();
    } catch (_) {}
  }

  Future<void> _fetchCallerName(String? callerId) async {
    if (callerId == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users_public')
          .doc(callerId)
          .get();
      final name = snap.data()?['fullName'] as String?;
      if (!mounted) return;
      setState(() => _incomingCallerName = name ?? callerId);
    } catch (_) {
      if (mounted) setState(() => _incomingCallerName = callerId);
    }
  }

  Future<void> _acceptIncomingCall() async {
    if (_activeIncomingCallId == null || _incomingCallerId == null) return;
    try {
      await _stopIncomingRingtone();
      await CallSessionService.acceptSession(_activeIncomingCallId!);
      if (!mounted) return;
      _open(
        context,
        VideoCallScreen(
          remoteUserId: _incomingCallerId,
          initialRemoteDisplayName: _incomingCallerName,
          callSessionId: _activeIncomingCallId,
          isCaller: false, // callee siempre es quien acepta
          audioOnly: _incomingAudioOnly,
        ),
      );
    } catch (_) {
      if (mounted) {
        ErrorPresenter.showSnack(
          context,
          'No se pudo aceptar la llamada.',
          state: RealtimeUxState.error,
          actionLabel: 'Reintentar',
          onAction: _acceptIncomingCall,
        );
      }
    }
  }

  Future<void> _rejectIncomingCall() async {
    if (_activeIncomingCallId == null) return;
    try {
      await _stopIncomingRingtone();
      await CallSessionService.rejectSession(_activeIncomingCallId!);
      if (!mounted) return;
      setState(() {
        _activeIncomingCallId = null;
        _incomingCallerId = null;
        _incomingCallerName = null;
        _incomingAudioOnly = true;
      });
    } catch (_) {}
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _openBottomSection(int index) {
    switch (index) {
      case 0:
        return;
      case 1:
        _open(context, const ChatHubScreen());
        return;
      case 2:
        _open(context, const CallScreen());
        return;
    }
  }

  void _showNumberOrbitInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF3F8FD),
        title: const Row(
          children: [
            Icon(Icons.info_rounded, color: Color(0xFF0A4D8F)),
            SizedBox(width: 8),
            Text(
              'Code Orbit',
              style: TextStyle(
                color: Color(0xFF0A4D8F),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tu Code Orbit es:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF123A5B),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F4FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBCD8EE)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '✨ Tu identificador amigable',
                      style: TextStyle(
                        color: Color(0xFF0A4D8F),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Es una versión corta y fácil de recordar de tu ID de usuario, perfecto para compartir con amigos.',
                      style: TextStyle(color: Color(0xFF5A7388), fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Usos:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF123A5B),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              const _InfoBullet(
                icon: Icons.call,
                title: 'Compartir en redes',
                description:
                    'Más fácil de compartir que tu ID completo. Ejemplo: "Llámame en Orbit: 12345678"',
              ),
              const SizedBox(height: 8),
              const _InfoBullet(
                icon: Icons.contacts,
                title: 'Guardar en contactos',
                description:
                    'Los amigos pueden guardarlo fácilmente en sus contactos de Orbit.',
              ),
              const SizedBox(height: 8),
              const _InfoBullet(
                icon: Icons.person_add,
                title: 'Agregar al directorio',
                description:
                    'Otros usuarios pueden encontrarte usando tu Code Orbit en la búsqueda.',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFCC80)),
                ),
                child: const Text(
                  '💡 Tip: Puedes compartir tu Code Orbit en redes sociales. Los datos viajan por tu ID único de verdad.',
                  style: TextStyle(
                    color: Color(0xFF5A3F00),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Entendido',
              style: TextStyle(color: Color(0xFF0A4D8F)),
            ),
          ),
        ],
      ),
    );
  }

  Drawer _buildHomeDrawer(String uid, String displayName) {
    return Drawer(
      backgroundColor: const Color(0xFFF7FAFE),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE9F4FF), Color(0xFFD9EEFF)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBCD8EE)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF62D2FF), Color(0xFF2F94FF)],
                      ),
                    ),
                    child: const Icon(Icons.menu_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF153B5A),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Text(
                          'Menú rápido',
                          style: TextStyle(
                            color: Color(0xFF4B78A1),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (uid.isNotEmpty) _buildOrbitNumberTile(uid),
            ListTile(
              leading: const Icon(
                Icons.history_rounded,
                color: Color(0xFF8FD5FF),
              ),
              title: const Text(
                'Historial',
                style: TextStyle(color: Color(0xFF153B5A)),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _open(context, const HistoryScreen());
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.settings_rounded,
                color: Color(0xFF93E2C5),
              ),
              title: const Text(
                'Configuracion',
                style: TextStyle(color: Color(0xFF153B5A)),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _open(context, const SettingsScreen());
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrbitNumberTile(String uid) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, userSnap) {
        final fromUser =
            userSnap.data?.data()?['orbitNumber']?.toString().trim();
        if (fromUser != null && fromUser.isNotEmpty) {
          return _orbitNumberTile(context, fromUser);
        }

        return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('orbitNumbers')
              .where('uid', isEqualTo: uid)
              .limit(1)
              .get(),
          builder: (context, numberSnap) {
            final fromIndex = numberSnap.data?.docs.isNotEmpty == true
                ? numberSnap.data!.docs.first.id
                : '-';
            return _orbitNumberTile(context, fromIndex);
          },
        );
      },
    );
  }

  Widget _orbitNumberTile(BuildContext context, String orbitNumber) {
    final canCopy = orbitNumber.trim().isNotEmpty && orbitNumber != '-';
    return ListTile(
      leading: const Icon(Icons.confirmation_number, color: Color(0xFFFFC46C)),
      title: const Text(
        'Code Orbit',
        style: TextStyle(color: Color(0xFF5A7388), fontSize: 12),
      ),
      subtitle: Text(
        orbitNumber,
        style: const TextStyle(
          color: Color(0xFF0D304D),
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '¿Cómo usar el Code Orbit?',
            icon: const Icon(
              Icons.info_outline,
              color: Color(0xFF0A4D8F),
              size: 20,
            ),
            onPressed: () => _showNumberOrbitInfoDialog(context),
          ),
          IconButton(
            tooltip: 'Copiar número',
            icon: const Icon(Icons.copy, color: Color(0xFF5A7388), size: 20),
            onPressed: canCopy
                ? () {
                    Clipboard.setData(ClipboardData(text: orbitNumber));
                    ErrorPresenter.showSnack(
                      context,
                      'Code Orbit copiado',
                      state: RealtimeUxState.delivered,
                    );
                  }
                : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.getCurrentUser();
    final uid = currentUser?.uid ?? '';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final now = DateTime.now();
        final isSecondPress = _lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2);
        if (isSecondPress) {
          SystemNavigator.pop();
          return;
        }
        _lastBackPress = now;
        ErrorPresenter.showSnack(
          context,
          'Presiona atrás de nuevo para salir',
          state: RealtimeUxState.queued,
          duration: const Duration(seconds: 2),
        );
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F8FD),
        appBar: AppBar(
          title: const Text('Orbit'),
          backgroundColor: const Color(0xFFFFFFFF),
          foregroundColor: const Color(0xFF0A4D8F),
          iconTheme: const IconThemeData(color: Color(0xFF0A4D8F)),
          titleTextStyle: const TextStyle(
            color: Color(0xFF0A4D8F),
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
          elevation: 2,
          centerTitle: true,
          leading: Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu_rounded),
              tooltip: 'Menu',
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Nuevo estado',
              onPressed: () => _open(context, const StatusScreen()),
              icon: Stack(
                clipBehavior: Clip.none,
                children: const [
                  Icon(Icons.camera_alt_rounded, color: Color(0xFF0A4D8F)),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Icon(
                      Icons.add_circle,
                      size: 14,
                      color: Color(0xFF0A4D8F),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
        drawer: _buildHomeDrawer(uid, _displayName),
        body: Column(
          children: [
          if (_homeRealtimeState != RealtimeUxState.online)
            ErrorPresenter.buildStatusStrip(
              state: _homeRealtimeState,
              message: _homeRealtimeMessage,
              onRetry: () {
                _refreshNetworkInsight();
                _listenForIncomingCalls();
              },
            ),
            // ── Barra compacta superior: Señal + IA ──────────────
            _CompactTopBar(
              networkLabel: _networkLabel,
              networkColor: _networkColor,
              latencyMs: _latencyMs,
              isSatellite: _isSatellite,
              recommendedMode: _recommendedMode,
              onOpenIa: () => _open(context, const OrbitIAScreen()),
            ),
            // ── Banner llamada entrante ──────────────────────────
            if (_activeIncomingCallId != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                child: IncomingCallBanner(
                  callerName: _incomingCallerName ?? 'Usuario Orbit',
                  onAccept: _acceptIncomingCall,
                  onReject: _rejectIncomingCall,
                ),
              ),
            // ── Lista de chats recientes (estilo WhatsApp) ───────
            Expanded(
              child: _RecentChatsList(
                currentUid: uid,
                onOpenChat: (contactUid, contactName) => _open(
                  context,
                  chat.ChatScreen(
                    remoteUserId: contactUid,
                    initialContactName: contactName,
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: 0,
          onTap: _openBottomSection,
          backgroundColor: const Color(0xFFFFFFFF),
          selectedItemColor: const Color(0xFF0A4D8F),
          unselectedItemColor: const Color(0xFF0A4D8F),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Inicio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_rounded),
              label: 'Chat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.call_rounded),
              label: 'Llamada',
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== SUPPORTING WIDGETS ====================

class _InfoBullet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _InfoBullet({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF0A4D8F), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF123A5B),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(color: Color(0xFF5A7388), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NetworkInsight {
  final String label;
  final Color color;
  final String recommendedMode;

  const _NetworkInsight({
    required this.label,
    required this.color,
    required this.recommendedMode,
  });
}

// ── Barra compacta superior: señal + IA ────────────────────────────────────
class _CompactTopBar extends StatelessWidget {
  final String networkLabel;
  final Color networkColor;
  final int? latencyMs;
  final bool isSatellite;
  final String recommendedMode;
  final VoidCallback onOpenIa;

  const _CompactTopBar({
    required this.networkLabel,
    required this.networkColor,
    required this.latencyMs,
    required this.isSatellite,
    required this.recommendedMode,
    required this.onOpenIa,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          Icon(Icons.signal_cellular_alt, color: networkColor, size: 16),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              latencyMs != null
                  ? '$networkLabel · ${latencyMs}ms'
                  : networkLabel,
              style: TextStyle(
                color: networkColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: onOpenIa,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF0A4D8F),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, size: 13, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    'IA · ${capitalize(recommendedMode)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

// ── Lista de chats recientes (estilo WhatsApp) ──────────────────────────────
class _RecentChatsList extends StatelessWidget {
  final String currentUid;
  final void Function(String contactUid, String contactName) onOpenChat;

  const _RecentChatsList({required this.currentUid, required this.onOpenChat});

  @override
  Widget build(BuildContext context) {
    if (currentUid.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ResilientStreamHelper.resilientStream<
          QuerySnapshot<Map<String, dynamic>>>(
        streamFactory: () => FirebaseFirestore.instance
            .collection('chatRooms')
            .where('participants', arrayContains: currentUid)
            .orderBy('updatedAt', descending: true)
            .limit(50)
            .snapshots(),
        timeout: const Duration(seconds: 15),
        logTag: 'HomeRecentChats:$currentUid',
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 12),
                Text(
                  'Sin conversaciones aún',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  'Toca Chat para iniciar una conversación',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: docs.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 70, color: Color(0xFFEFF3F7)),
          itemBuilder: (context, i) {
            final room = docs[i].data();
            final participants = List<String>.from(
              room['participants'] as List? ?? [],
            );
            final otherUid = participants.firstWhere(
              (p) => p != currentUid,
              orElse: () => currentUid,
            );
            // Skip stale rooms with invalid/non-UID participants
            if (otherUid.length < 10 ||
                !RegExp(r'^[a-zA-Z0-9]+$').hasMatch(otherUid)) {
              return const SizedBox.shrink();
            }
            final lastMsg = room['lastMessage'] as String? ?? '';
            final lastMsgType = room['lastMessageType'] as String? ?? 'text';
            final updatedAt = room['updatedAt'];
            final unread = (room['unread_$currentUid'] as int?) ?? 0;

            return _ChatRoomTile(
              otherUid: otherUid,
              lastMessage: lastMsg,
              lastMessageType: lastMsgType,
              updatedAt: updatedAt,
              unreadCount: unread,
              onTap: (contactName) => onOpenChat(otherUid, contactName),
            );
          },
        );
      },
    );
  }
}

class _ChatRoomTile extends StatelessWidget {
  final String otherUid;
  final String lastMessage;
  final String lastMessageType;
  final dynamic updatedAt;
  final int unreadCount;
  final void Function(String contactName) onTap;

  const _ChatRoomTile({
    required this.otherUid,
    required this.lastMessage,
    required this.lastMessageType,
    required this.updatedAt,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users_public')
          .doc(otherUid)
          .get(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data();
        final name =
            (userData?['fullName'] as String?)?.trim().isNotEmpty == true
                ? userData!['fullName'] as String
                : otherUid;
        final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

        String timeStr = '';
        if (updatedAt is Timestamp) {
          final dt = (updatedAt as Timestamp).toDate();
          final now = DateTime.now();
          if (dt.year == now.year &&
              dt.month == now.month &&
              dt.day == now.day) {
            timeStr =
                '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
          } else {
            timeStr = '${dt.day}/${dt.month}';
          }
        }

        String preview = lastMessage;
        if (lastMessageType == 'image') preview = '📷 Imagen';
        if (lastMessageType == 'audio') preview = '🎤 Audio';
        if (lastMessageType == 'file') preview = '📎 Archivo';
        if (preview.isEmpty) preview = 'Toca para abrir el chat';

        return InkWell(
          onTap: () => onTap(name),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF62D2FF), Color(0xFF2F94FF)],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Nombre + preview
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: const Color(0xFF16324F),
                          fontWeight: unreadCount > 0
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preview,
                        style: TextStyle(
                          color: unreadCount > 0
                              ? const Color(0xFF0A4D8F)
                              : const Color(0xFF8AA4BF),
                          fontSize: 13,
                          fontWeight: unreadCount > 0
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Hora + badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timeStr,
                      style: TextStyle(
                        color: unreadCount > 0
                            ? const Color(0xFF0A4D8F)
                            : const Color(0xFFADBCC9),
                        fontSize: 11,
                      ),
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0A4D8F),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ...existing code...
// ...existing code...
class IncomingCallBanner extends StatelessWidget {
  final String callerName;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const IncomingCallBanner({
    super.key,
    required this.callerName,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE0E0), Color(0xFFFFD0D0)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF6B6B)),
      ),
      child: Column(
        children: [
          Text(
            '$callerName te está llamando...',
            style: const TextStyle(
              color: Color(0xFFE53935),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.call_end),
                  label: const Text('Rechazar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onAccept,
                  icon: const Icon(Icons.call),
                  label: const Text('Aceptar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF43A047),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

//
//
