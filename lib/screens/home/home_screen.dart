import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Home tabs
import 'history_screen.dart';
import 'settings_screen.dart';
import 'status_screen.dart';

// Communication
import '../communication/call_screen.dart';
import '../communication/chat_screen.dart';
import '../communication/video_call_screen.dart';

// Services
import '../../services/auth_service.dart';
import '../../services/call_session_service.dart';
import '../../services/network_service.dart';

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
  String? _activeIncomingCallId;
  String? _incomingCallerId;
  String? _incomingCallerName;

  Timer? _networkTimer;

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
    _incomingCallSub?.cancel();
    super.dispose();
  }

  Future<void> _loadUserDisplay() async {
    final user = AuthService.getCurrentUser();
    if (!mounted) return;
    setState(() {
      _displayName = user?.displayName ?? user?.uid ?? 'Usuario ORBIT';
    });
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
    });
  }

  _NetworkInsight _buildNetworkInsight(String quality, int? latencyMs) {
    if (quality == 'none') {
      return const _NetworkInsight(
        label: 'Sin conexiÃ³n',
        color: Color(0xFFE15759),
        recommendedMode: 'chat',
      );
    }
    if (quality == 'low') {
      return const _NetworkInsight(
        label: 'SeÃ±al inestable',
        color: Color(0xFFF28E2B),
        recommendedMode: 'chat',
      );
    }
    if (quality == 'medium') {
      if (latencyMs != null && latencyMs > 240) {
        return const _NetworkInsight(
          label: 'SeÃ±al media, latencia alta',
          color: Color(0xFFF1C453),
          recommendedMode: 'chat',
        );
      }
      return const _NetworkInsight(
        label: 'SeÃ±al media',
        color: Color(0xFFE0C15A),
        recommendedMode: 'voz o chat',
      );
    }
    if (latencyMs != null && latencyMs > 200) {
      return const _NetworkInsight(
        label: 'SeÃ±al alta, latencia variable',
        color: Color(0xFF63D5A8),
        recommendedMode: 'llamada de voz',
      );
    }
    return const _NetworkInsight(
      label: 'SeÃ±al Ã³ptima',
      color: Color(0xFF4ECCA3),
      recommendedMode: 'todos los servicios',
    );
  }

  void _listenForIncomingCalls() {
    final uid = AuthService.getCurrentUser()?.uid;
    if (uid == null) return;

    _incomingCallSub =
        CallSessionService.incomingRingingStream().listen((snap) {
      if (snap.docs.isEmpty) {
        if (!mounted) return;
        setState(() {
          _activeIncomingCallId = null;
          _incomingCallerId = null;
          _incomingCallerName = null;
        });
        return;
      }

      final callDoc = snap.docs.first;
      final session = callDoc.data();
      final status = session['status'] as String?;

      if (status == 'ringing' && _activeIncomingCallId != callDoc.id) {
        if (!mounted) return;
        setState(() {
          _activeIncomingCallId = callDoc.id;
          _incomingCallerId = session['callerId'] as String?;
        });
        _fetchCallerName(_incomingCallerId);
      } else if (status == 'accepted' ||
          status == 'ended' ||
          status == 'rejected') {
        if (!mounted) return;
        setState(() => _activeIncomingCallId = null);
      }
    });
  }

  Future<void> _fetchCallerName(String? callerId) async {
    if (callerId == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
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
      await CallSessionService.acceptSession(_activeIncomingCallId!);
      if (!mounted) return;
      _open(
        context,
        VideoCallScreen(
          remoteUserId: _incomingCallerId,
          callSessionId: _activeIncomingCallId,
          isCaller: false, // callee siempre es quien acepta
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al aceptar llamada')),
        );
      }
    }
  }

  Future<void> _rejectIncomingCall() async {
    if (_activeIncomingCallId == null) return;
    try {
      await CallSessionService.rejectSession(_activeIncomingCallId!);
      if (!mounted) return;
      setState(() => _activeIncomingCallId = null);
    } catch (_) {}
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Future<String?> _promptRemoteIdentifier({
    required String title,
    required String actionLabel,
  }) async {
    final controller = TextEditingController();
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Numero Orbit o UID',
            hintText: 'Ejemplo: 12345678 o UID exacto',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    return selected;
  }

  Future<void> _openDirectChat() async {
    final remoteUid = await AuthService.resolveUserIdFromContactIdentifier(
      (await _promptRemoteIdentifier(
            title: 'Iniciar Chat',
            actionLabel: 'Chatear',
          )) ??
          '',
    );

    if (!mounted) return;

    if (remoteUid == null || remoteUid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('ID no vÃ¡lido')));
      }
      return;
    }

    _open(context, ChatScreen(contactNameOrId: remoteUid));
  }

  Future<void> _openDirectVideoCall() async {
    final remoteUid = await AuthService.resolveUserIdFromContactIdentifier(
      (await _promptRemoteIdentifier(
            title: 'Iniciar Videollamada',
            actionLabel: 'Videollamar',
          )) ??
          '',
    );

    if (!mounted) return;

    if (remoteUid == null || remoteUid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('ID no vÃ¡lido')));
      }
      return;
    }

    _open(
      context,
      VideoCallScreen(
        remoteUserId: remoteUid,
        isCaller: true,
      ),
    );
  }

  void _openBottomSection(int index) {
    switch (index) {
      case 0:
        return;
      case 1:
        unawaited(_openDirectChat());
        return;
      case 2:
        _open(context, const CallScreen());
        return;
      case 3:
        unawaited(_openDirectVideoCall());
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
              'NÃºmero Orbit',
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
                'Tu NÃºmero Orbit es:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF123A5B),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F4FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBCD8EE)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'âœ¨ Tu identificador amigable',
                      style: TextStyle(
                        color: Color(0xFF0A4D8F),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Es una versiÃ³n corta y fÃ¡cil de recordar de tu ID de usuario, perfecto para compartir con amigos.',
                      style: TextStyle(
                        color: Color(0xFF5A7388),
                        fontSize: 11,
                      ),
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
                    'MÃ¡s fÃ¡cil de compartir que tu ID completo. Ejemplo: "LlÃ¡mame en Orbit: 12345678"',
              ),
              const SizedBox(height: 8),
              const _InfoBullet(
                icon: Icons.contacts,
                title: 'Guardar en contactos',
                description:
                    'Los amigos pueden guardarlo fÃ¡cilmente en sus contactos de Orbit.',
              ),
              const SizedBox(height: 8),
              const _InfoBullet(
                icon: Icons.person_add,
                title: 'Agregar al directorio',
                description:
                    'Otros usuarios pueden encontrarte usando tu NÃºmero Orbit en la bÃºsqueda.',
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
                  'ðŸ’¡ Tip: Puedes compartir tu NÃºmero Orbit en redes sociales. Los datos viajan por tu ID Ãºnico de verdad.',
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
                  const Expanded(
                    child: Text(
                      'Menu rapido',
                      style: TextStyle(
                        color: Color(0xFF153B5A),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (uid.isNotEmpty) _buildOrbitNumberTile(uid),
            ListTile(
              leading:
                  const Icon(Icons.history_rounded, color: Color(0xFF8FD5FF)),
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
              leading:
                  const Icon(Icons.settings_rounded, color: Color(0xFF93E2C5)),
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
      leading: const Icon(
        Icons.confirmation_number,
        color: Color(0xFFFFC46C),
      ),
      title: const Text(
        'NÃºmero Orbit',
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
            tooltip: 'Â¿CÃ³mo usar el NÃºmero Orbit?',
            icon: const Icon(Icons.info_outline,
                color: Color(0xFF0A4D8F), size: 20),
            onPressed: () => _showNumberOrbitInfoDialog(context),
          ),
          IconButton(
            tooltip: 'Copiar nÃºmero',
            icon: const Icon(Icons.copy, color: Color(0xFF5A7388), size: 20),
            onPressed: canCopy
                ? () {
                    Clipboard.setData(ClipboardData(text: orbitNumber));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('NÃºmero Orbit copiado')),
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

    return Scaffold(
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _HeroSection(
                networkLabel: _networkLabel,
                networkColor: _networkColor,
                latencyMs: _latencyMs,
                isSatellite: _isSatellite,
              ),
              const SizedBox(height: 14),
              if (_activeIncomingCallId != null)
                _IncomingCallBanner(
                  callerName: _incomingCallerName ?? 'Usuario Orbit',
                  onAccept: _acceptIncomingCall,
                  onReject: _rejectIncomingCall,
                ),
              if (_activeIncomingCallId != null) const SizedBox(height: 14),
              const _SectionTitle(title: 'Orbit IA Recomienda'),
              const SizedBox(height: 8),
              _IaInsightCard(
                networkLabel: _networkLabel,
                recommendedMode: _recommendedMode,
                latencyMs: _latencyMs,
                isSatellite: _isSatellite,
                onOpenIa: () => _open(context, const OrbitIAScreen()),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
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
          BottomNavigationBarItem(
            icon: Icon(Icons.videocam_rounded),
            label: 'Video',
          ),
        ],
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
                style: const TextStyle(
                  color: Color(0xFF5A7388),
                  fontSize: 11,
                ),
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

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF4D6880),
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final String networkLabel;
  final Color networkColor;
  final int? latencyMs;
  final bool isSatellite;

  const _HeroSection({
    required this.networkLabel,
    required this.networkColor,
    required this.latencyMs,
    required this.isSatellite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE9F4FF), Color(0xFFD9EEFF)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBCD8EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_done_rounded, color: networkColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  networkLabel,
                  style: TextStyle(
                    color: networkColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _MetricPill(
                icon: Icons.speed,
                value: latencyMs?.toString() ?? '-',
                unit: 'ms',
                color: networkColor,
              ),
              _MetricPill(
                icon: Icons.router,
                value: isSatellite ? 'ðŸ›°ï¸' : 'ðŸ“¶',
                unit: isSatellite ? 'SatÃ©lite' : 'IP',
                color: networkColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  final Color color;

  const _MetricPill({
    required this.icon,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$value $unit',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomingCallBanner extends StatelessWidget {
  final String callerName;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _IncomingCallBanner({
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
            '$callerName te estÃ¡ llamando...',
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

class _IaInsightCard extends StatelessWidget {
  final String networkLabel;
  final String recommendedMode;
  final int? latencyMs;
  final bool isSatellite;
  final VoidCallback onOpenIa;

  const _IaInsightCard({
    required this.networkLabel,
    required this.recommendedMode,
    required this.latencyMs,
    required this.isSatellite,
    required this.onOpenIa,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBCD8EE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_rounded,
                  color: Color(0xFFFFC46C), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'RecomendaciÃ³n: $recommendedMode',
                  style: const TextStyle(
                    color: Color(0xFF0A4D8F),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tu red estÃ¡ lista para: ${recommendedMode.capitalizeFirst()}',
            style: const TextStyle(
              color: Color(0xFF5A7388),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: onOpenIa,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A4D8F),
              minimumSize: const Size(double.infinity, 36),
            ),
            child: const Text(
              'Abrir Orbit IA',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

extension on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}
