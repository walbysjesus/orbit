import 'package:flutter/material.dart';
import 'profile_edit_screen.dart';
import 'security_edit_screen.dart';
import '../../services/auth_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: const Color(0xFF001F3F),
        elevation: 0,
      ),
      body: ListView(
        children: [
          Semantics(
            label: 'Editar perfil',
            child: ListTile(
              leading: const Icon(Icons.person, color: Colors.white),
              title: const Text('Perfil', style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ProfileEditScreen()),
                );
              },
            ),
          ),
          Semantics(
            label: 'Seguridad',
            child: ListTile(
              leading: const Icon(Icons.security, color: Colors.white),
              title: const Text('Seguridad', style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => SecurityEditScreen()),
                );
              },
            ),
          ),
          // ...existing code...
          const Divider(color: Colors.white24),
          Semantics(
            label: 'Cerrar sesión',
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Cerrar sesión', style: TextStyle(color: Colors.white)),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('¿Cerrar sesión?'),
                    content: const Text('¿Estás seguro que deseas salir de tu cuenta?'),
                    actions: [
                      TextButton(
                        child: const Text('Cancelar'),
                        onPressed: () => Navigator.of(ctx).pop(false),
                      ),
                      TextButton(
                        child: const Text('Cerrar sesión'),
                        onPressed: () => Navigator.of(ctx).pop(true),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await AuthService.logout();
                  if (!context.mounted) return;
                  Navigator.pushReplacementNamed(context, '/login');
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesión cerrada')));
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
