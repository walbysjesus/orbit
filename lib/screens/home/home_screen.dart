import 'package:flutter/material.dart';

// Home tabs
import 'dashboard_screen.dart';
import 'contacts_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

// Communication
import '../communication/call_screen.dart';
import '../communication/chat_screen.dart';
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

  final List<Widget> _pages = const [
    DashboardScreen(),
    ContactsScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  void _open(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      // ───── APP BAR ─────
      appBar: AppBar(
        title: const Text(
          'Orbit',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
      ),

      // ───── BODY ─────
      body: Column(
        children: [
          // STATUS BAR (clave para Orbit)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: const [
                Icon(Icons.satellite_alt, color: Colors.green),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Red satelital activa · Señal estable',
                    style: TextStyle(color: Colors.white),
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
                  icon: Icons.call,
                  title: 'Llamada',
                  onTap: () => _open(context, const CallScreen()),
                ),
                _ActionCard(
                  icon: Icons.chat,
                  title: 'Chat',
                  onTap: () => _open(context, const ChatScreen()),
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

          // MAIN CONTENT
          Expanded(
            child: _pages[_currentIndex],
          ),
        ],
      ),

      // ───── BOTTOM NAV ─────
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
              color: Colors.black.withOpacity(0.05),
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
