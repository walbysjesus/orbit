import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_edit_screen.dart';
import 'security_edit_screen.dart';
import '../../services/auth_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8FD),
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: const Color(0xFFFFFFFF),
        foregroundColor: const Color(0xFF0A4D8F),
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFDFEFF), Color(0xFFECF5FC)],
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - value) * 12),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFFFFF), Color(0xFFEAF5FE)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFC9DEEE)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1E486D),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.verified_user,
                            color: Color(0xFF8BD4FF)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Panel de cuenta Orbit',
                              style: TextStyle(
                                color: Color(0xFF123A5B),
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              uid.isEmpty
                                  ? 'Sin sesión activa'
                                  : 'Sesión activa',
                              style: const TextStyle(color: Color(0xFF4D6880)),
                            ),
                          ],
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: uid.isEmpty
                              ? const Color(0xFF59313A)
                              : const Color(0xFF1F5A4A),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          uid.isEmpty ? 'Offline' : 'Online',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const _SettingsSectionTitle('Cuenta Orbit'),
              Card(
                color: const Color(0xFFFFFFFF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: uid.isEmpty
                    ? const ListTile(
                        leading: Icon(Icons.confirmation_number,
                            color: Color(0xFFFFB347)),
                        title: Text('Tu numero Orbit',
                            style: TextStyle(color: Color(0xFF123A5B))),
                        subtitle: Text('(sin sesion)',
                            style: TextStyle(color: Color(0xFF5A7388))),
                      )
                    : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .snapshots(),
                        builder: (context, snapshot) {
                          final orbitNumber =
                              snapshot.data?.data()?['orbitNumber']?.toString();
                          final value =
                              (orbitNumber == null || orbitNumber.isEmpty)
                                  ? '(no asignado aun)'
                                  : orbitNumber;

                          return ListTile(
                            leading: const Icon(Icons.confirmation_number,
                                color: Color(0xFFFFB347)),
                            title: const Text('Tu numero Orbit',
                                style: TextStyle(color: Color(0xFF123A5B))),
                            subtitle: Text(
                              value,
                              style: const TextStyle(
                                color: Color(0xFF5A7388),
                                fontSize: 14,
                                fontFamily: 'monospace',
                              ),
                            ),
                            trailing:
                                (orbitNumber == null || orbitNumber.isEmpty)
                                    ? null
                                    : IconButton(
                                        icon: const Icon(Icons.copy,
                                            color: Color(0xFF5A7388), size: 20),
                                        tooltip: 'Copiar numero Orbit',
                                        onPressed: () {
                                          HapticFeedback.selectionClick();
                                          Clipboard.setData(
                                              ClipboardData(text: orbitNumber));
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Numero Orbit copiado al portapapeles'),
                                            ),
                                          );
                                        },
                                      ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 4),
              Card(
                color: const Color(0xFFFFFFFF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading:
                      const Icon(Icons.fingerprint, color: Color(0xFF00C9FF)),
                  title: const Text('Tu ID de usuario',
                      style: TextStyle(color: Color(0xFF123A5B))),
                  subtitle: Text(
                    uid.isEmpty ? '(sin sesión)' : uid,
                    style: const TextStyle(
                        color: Color(0xFF5A7388),
                        fontSize: 11,
                        fontFamily: 'monospace'),
                  ),
                  trailing: uid.isEmpty
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.info_outline,
                                  color: Color(0xFF0A4D8F), size: 20),
                              tooltip: '¿Para qué sirve el ID?',
                              onPressed: () => _showUidInfoDialog(context),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy,
                                  color: Color(0xFF5A7388), size: 20),
                              tooltip: 'Copiar ID',
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                Clipboard.setData(ClipboardData(text: uid));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('ID copiado al portapapeles')),
                                );
                              },
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              const _SettingsSectionTitle('Perfil y Seguridad'),
              Card(
                color: const Color(0xFFFFFFFF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Semantics(
                  label: 'Editar perfil',
                  child: ListTile(
                    leading: const Icon(Icons.person, color: Color(0xFF00C9FF)),
                    title: const Text('Perfil',
                        style: TextStyle(color: Color(0xFF123A5B))),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        color: Color(0xFF5A7388), size: 16),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ProfileEditScreen()),
                      );
                    },
                  ),
                ),
              ),
              Card(
                color: const Color(0xFFFFFFFF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Semantics(
                  label: 'Seguridad',
                  child: ListTile(
                    leading:
                        const Icon(Icons.security, color: Color(0xFFFFB347)),
                    title: const Text('Seguridad',
                        style: TextStyle(color: Color(0xFF123A5B))),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        color: Color(0xFF5A7388), size: 16),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => SecurityEditScreen()),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const _SettingsSectionTitle('Preferencias de comunicación'),
              Card(
                color: const Color(0xFFFFFFFF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: const ListTile(
                  leading: Icon(Icons.network_check, color: Color(0xFF8BD4FF)),
                  title: Text('Modo automático por señal',
                      style: TextStyle(color: Color(0xFF123A5B))),
                  subtitle: Text(
                    'Orbit recomienda chat, voz o video según la red.',
                    style: TextStyle(color: Color(0xFF4D6880)),
                  ),
                ),
              ),
              Card(
                color: const Color(0xFFFFFFFF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: const ListTile(
                  leading: Icon(Icons.notifications_active,
                      color: Color(0xFFFFC46C)),
                  title: Text('Notificaciones de llamada',
                      style: TextStyle(color: Color(0xFF123A5B))),
                  subtitle: Text(
                    'Push activas para llamadas entrantes en segundo plano.',
                    style: TextStyle(color: Color(0xFF4D6880)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const _SettingsSectionTitle('Sesión'),
              Card(
                color: const Color(0xFFFFFFFF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Semantics(
                  label: 'Cerrar sesión',
                  child: ListTile(
                    leading: const Icon(Icons.logout, color: Colors.redAccent),
                    title: const Text('Cerrar sesión',
                        style: TextStyle(color: Color(0xFF123A5B))),
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('¿Cerrar sesión?'),
                          content: const Text(
                              '¿Estás seguro que deseas salir de tu cuenta?'),
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
                        HapticFeedback.mediumImpact();
                        await AuthService.logout();
                        if (!context.mounted) return;
                        Navigator.of(context)
                            .pushNamedAndRemoveUntil('/', (route) => false);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sesión cerrada')));
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showUidInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF3F8FD),
        title: const Row(
          children: [
            Icon(Icons.info_rounded, color: Color(0xFF0A4D8F)),
            SizedBox(width: 8),
            Text(
              'ID de Usuario Orbit',
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
                '¿Para qué sirve tu ID?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF123A5B),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              const _InfoBullet(
                icon: Icons.phone,
                title: 'Recibir llamadas',
                description:
                    'Comparte tu ID con otros para que puedan hacer videollamadas o llamadas de voz contigo.',
              ),
              const SizedBox(height: 10),
              const _InfoBullet(
                icon: Icons.chat,
                title: 'Iniciar chats',
                description:
                    'Los usuarios necesitan tu ID para enviarte mensajes y contenido multimedia.',
              ),
              const SizedBox(height: 10),
              const _InfoBullet(
                icon: Icons.security,
                title: 'Identificación única',
                description:
                    'Tu ID es único en Orbit y vinculado a tu cuenta de autenticación para seguridad.',
              ),
              const SizedBox(height: 10),
              const _InfoBullet(
                icon: Icons.backup_outlined,
                title: 'Sincronización',
                description:
                    'Todos tus datos (mensajes, histórico, configuración) se guardan bajo tu ID.',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F4FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBCD8EE)),
                ),
                child: const Text(
                  '💡 Tip: Puedes compartir tu ID o tu Número Orbit (más corto) para que otros te contacten.',
                  style: TextStyle(
                    color: Color(0xFF123A5B),
                    fontSize: 12,
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
}

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

class _SettingsSectionTitle extends StatelessWidget {
  final String text;

  const _SettingsSectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      child: Text(
        text,
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
