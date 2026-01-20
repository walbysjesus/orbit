import 'package:flutter/material.dart';

// Home tabs
import 'dashboard_screen.dart';
import 'contacts_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'status_screen.dart';

// Communication
import '../communication/call_screen.dart';
import '../communication/chat_screen.dart';
import '../../services/auth_service.dart';
import '../communication/video_call_screen.dart';

// Orbit IA
import '../ia/orbit_ia_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  String _displayName = 'Usuario ORBIT';
  String? _feedbackMsg;
  bool _isLoadingUser = false;
  bool _isNetworkStable = true;

  @override
  void initState() {
    super.initState();
    _loadUserDisplay();
    _checkNetworkStatus();
  }

  Future<void> _loadUserDisplay() async {
    setState(() { _isLoadingUser = true; _feedbackMsg = null; });
    try {
      final user = AuthService.getCurrentUser();
      setState(() {
        _displayName = user?.displayName ?? user?.uid ?? 'Usuario ORBIT';
        _isLoadingUser = false;
      });
    } catch (e) {
      setState(() {
        _feedbackMsg = 'Error al cargar usuario: ' + e.toString().replaceAll('Exception:', '').trim();
        _isLoadingUser = false;
      });
    }
  }

  final List<Widget> _pages = const [
    DashboardScreen(),
    ContactsScreen(),
    StatusScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  Future<void> _checkNetworkStatus() async {
    // Simulación de chequeo de red satelital
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _isNetworkStable = true; // Cambia a false si detectas problemas reales
    });
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ajuste visual: SafeArea + SingleChildScrollView para evitar overflow en pantallas pequeñas/teclado
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      appBar: AppBar(
        title: _isLoadingUser
            ? const Text('Cargando usuario...', style: TextStyle(fontWeight: FontWeight.w600))
            : Text(_displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (_feedbackMsg != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(_feedbackMsg!, style: const TextStyle(color: Colors.redAccent)),
                ),
              // STATUS BAR (clave para Orbit)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.satellite_alt, color: _isNetworkStable ? Colors.green : Colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isNetworkStable ? 'Red satelital activa · Señal estable' : 'Red satelital inactiva · Sin señal',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

              // QUICK ACTIONS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.2,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _ActionCard(
                      icon: Icons.psychology,
                      title: 'Orbit IA',
                      onTap: () => _open(context, const OrbitIAScreen()),
                    ),
                    _ActionCard(
                      icon: Icons.camera_alt,
                      title: 'Estados',
                      onTap: () => _open(context, const StatusScreen()),
                    ),
                    _ActionCard(
                      icon: Icons.call,
                      title: 'Llamada',
                      onTap: () => _open(context, const CallScreen()),
                    ),
                    _ActionCard(
                      icon: Icons.chat,
                      title: 'Chat',
                      onTap: () => _open(context, ChatScreen(contactNameOrId: _displayName)),
                    ),
                    _ActionCard(
                      icon: Icons.videocam,
                      title: 'Video',
                      onTap: () => _open(context, const VideoCallScreen()),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                height: MediaQuery.of(context).size.height * 0.45,
                child: _pages[_currentIndex],
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts),
            label: 'Contactos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Estados',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historial',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
