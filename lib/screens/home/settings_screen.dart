import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF001F3F),
        elevation: 0,
      ),
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.person, color: Colors.white),
            title: Text('Profile', style: TextStyle(color: Colors.white)),
          ),
          ListTile(
            leading: Icon(Icons.security, color: Colors.white),
            title: Text('Security', style: TextStyle(color: Colors.white)),
          ),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.redAccent),
            title: Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
