import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'profile_edit_screen.dart';
import 'security_edit_screen.dart';
import '../../services/auth_service.dart';
import '../../services/organization_service.dart';
import '../../services/resilient_stream_helper.dart';

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
                        title: Text('Tu Code Orbit',
                            style: TextStyle(color: Color(0xFF123A5B))),
                        subtitle: Text('(sin sesion)',
                            style: TextStyle(color: Color(0xFF5A7388))),
                      )
                    : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: ResilientStreamHelper.resilientStream<
                            DocumentSnapshot<Map<String, dynamic>>>(
                          streamFactory: () => FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .snapshots(),
                          timeout: const Duration(seconds: 15),
                          logTag: 'SettingsUserOrbitCode:$uid',
                        ),
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
                            title: const Text('Tu Code Orbit',
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
                                        tooltip: 'Copiar Code Orbit',
                                        onPressed: () {
                                          HapticFeedback.selectionClick();
                                          Clipboard.setData(
                                              ClipboardData(text: orbitNumber));
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Code Orbit copiado al portapapeles'),
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
              const _SettingsSectionTitle('Organización'),
              Card(
                color: const Color(0xFFFFFFFF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: uid.isEmpty
                    ? const ListTile(
                        leading:
                            Icon(Icons.apartment, color: Color(0xFF8AA4BF)),
                        title: Text('Organización',
                            style: TextStyle(color: Color(0xFF123A5B))),
                        subtitle: Text(
                          'Inicia sesión para ver cupos',
                          style: TextStyle(color: Color(0xFF5A7388)),
                        ),
                      )
                    : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: ResilientStreamHelper.resilientStream<
                            DocumentSnapshot<Map<String, dynamic>>>(
                          streamFactory: () => FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .snapshots(),
                          timeout: const Duration(seconds: 15),
                          logTag: 'SettingsUserOrg:$uid',
                        ),
                        builder: (context, userSnap) {
                          final userData = userSnap.data?.data();
                          final orgId =
                              (userData?['organizationId'] as String?)?.trim();
                          final role =
                              (userData?['organizationRole'] as String?)
                                  ?.trim();

                          if (orgId == null || orgId.isEmpty) {
                            return const ListTile(
                              leading: Icon(Icons.apartment,
                                  color: Color(0xFF8AA4BF)),
                              title: Text('Organización',
                                  style: TextStyle(color: Color(0xFF123A5B))),
                              subtitle: Text(
                                'Cuenta individual (sin organización)',
                                style: TextStyle(color: Color(0xFF5A7388)),
                              ),
                            );
                          }

                          return StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>>(
                            stream: ResilientStreamHelper.resilientStream<
                                DocumentSnapshot<Map<String, dynamic>>>(
                              streamFactory: () => FirebaseFirestore.instance
                                  .collection('organizations')
                                  .doc(orgId)
                                  .snapshots(),
                              timeout: const Duration(seconds: 15),
                              logTag: 'SettingsOrganization:$orgId',
                            ),
                            builder: (context, orgSnap) {
                              final orgData = orgSnap.data?.data();
                              final orgName = (orgData?['name'] as String?) ??
                                  'Organización';
                              final sector =
                                  (orgData?['sector'] as String?) ?? 'empresa';
                              final purchased =
                                  (orgData?['seatsPurchased'] as num?)
                                          ?.toInt() ??
                                      0;
                              final used =
                                  (orgData?['seatsUsed'] as num?)?.toInt() ?? 0;
                              final available =
                                  (purchased - used).clamp(0, 999999);
                              final usageRatio = purchased <= 0
                                  ? 0.0
                                  : (used / purchased).clamp(0.0, 1.0);
                              final isAdmin = role == 'admin';

                              return Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.apartment,
                                            color: Color(0xFF0A4D8F)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            orgName,
                                            style: const TextStyle(
                                              color: Color(0xFF123A5B),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isAdmin
                                                ? const Color(0xFF1F5A4A)
                                                : const Color(0xFF4C5D6D),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            isAdmin ? 'Admin' : 'Empleado',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Sector: $sector',
                                      style: const TextStyle(
                                          color: Color(0xFF5A7388)),
                                    ),
                                    const SizedBox(height: 4),
                                    SelectableText(
                                      'ID: $orgId',
                                      style: const TextStyle(
                                        color: Color(0xFF5A7388),
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Cupos: $used/$purchased usados · $available disponibles',
                                      style: const TextStyle(
                                          color: Color(0xFF123A5B),
                                          fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 8),
                                    LinearProgressIndicator(
                                      value: usageRatio,
                                      minHeight: 7,
                                      borderRadius: BorderRadius.circular(999),
                                      backgroundColor: const Color(0xFFE2ECF5),
                                      valueColor: const AlwaysStoppedAnimation(
                                        Color(0xFF0A8F6A),
                                      ),
                                    ),
                                    if (isAdmin) ...[
                                      const SizedBox(height: 12),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: ElevatedButton.icon(
                                          onPressed: () =>
                                              _showExpandSeatsDialog(
                                            context,
                                            orgId: orgId,
                                            adminUid: uid,
                                          ),
                                          icon: const Icon(
                                              Icons.add_circle_outline),
                                          label: const Text('Ampliar cupos'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF0A4D8F),
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              if (uid.isNotEmpty)
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: ResilientStreamHelper.resilientStream<
                      DocumentSnapshot<Map<String, dynamic>>>(
                    streamFactory: () => FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .snapshots(),
                    timeout: const Duration(seconds: 15),
                    logTag: 'SettingsAdminGuard:$uid',
                  ),
                  builder: (context, userSnap) {
                    final userData = userSnap.data?.data();
                    final orgId =
                        (userData?['organizationId'] as String?)?.trim();
                    final role =
                        (userData?['organizationRole'] as String?)?.trim();
                    final isAdmin =
                        orgId != null && orgId.isNotEmpty && role == 'admin';
                    if (!isAdmin) return const SizedBox.shrink();

                    return Column(
                      children: [
                        Card(
                          color: const Color(0xFFFFFFFF),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          child: StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>>(
                            stream: ResilientStreamHelper.resilientStream<
                                DocumentSnapshot<Map<String, dynamic>>>(
                              streamFactory: () => FirebaseFirestore.instance
                                  .collection('organizationUsage')
                                  .doc(orgId)
                                  .snapshots(),
                              timeout: const Duration(seconds: 15),
                              logTag: 'SettingsOrgUsage:$orgId',
                            ),
                            builder: (context, usageSnap) {
                              final usage = usageSnap.data?.data() ?? {};
                              final messages =
                                  (usage['messagesSent'] as num?)?.toInt() ?? 0;
                              final minutes =
                                  (usage['minutesUsed'] as num?)?.toInt() ?? 0;

                              return ListTile(
                                leading: const Icon(Icons.analytics,
                                    color: Color(0xFF0A4D8F)),
                                title: const Text('Consumo de la organización',
                                    style: TextStyle(color: Color(0xFF123A5B))),
                                subtitle: Text(
                                  'Mensajes: $messages · Minutos voz/video: $minutes',
                                  style:
                                      const TextStyle(color: Color(0xFF5A7388)),
                                ),
                              );
                            },
                          ),
                        ),
                        Card(
                          color: const Color(0xFFFFFFFF),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.group,
                                    color: Color(0xFF0A8F6A)),
                                title: const Text('Miembros de la organización',
                                    style: TextStyle(color: Color(0xFF123A5B))),
                                trailing: TextButton.icon(
                                  onPressed: () => _showInviteDialog(
                                    context,
                                    orgId: orgId,
                                    adminUid: uid,
                                  ),
                                  icon: const Icon(Icons.person_add_alt_1),
                                  label: const Text('Invitar'),
                                ),
                              ),
                              StreamBuilder<
                                  QuerySnapshot<Map<String, dynamic>>>(
                                stream:
                                    OrganizationService.membersStream(orgId),
                                builder: (context, membersSnap) {
                                  final docs =
                                      membersSnap.data?.docs ?? const [];
                                  if (docs.isEmpty) {
                                    return const Padding(
                                      padding: EdgeInsets.only(bottom: 14),
                                      child: Text(
                                        'Sin miembros registrados',
                                        style:
                                            TextStyle(color: Color(0xFF5A7388)),
                                      ),
                                    );
                                  }

                                  return Column(
                                    children: docs.map((doc) {
                                      final d = doc.data();
                                      final memberUid =
                                          (d['uid'] as String?) ?? '';
                                      final memberRole =
                                          (d['role'] as String?) ?? 'employee';
                                      final active =
                                          d['active'] as bool? ?? false;
                                      final canToggle = memberRole != 'admin';

                                      return ListTile(
                                        dense: true,
                                        leading: Icon(
                                          memberRole == 'admin'
                                              ? Icons.admin_panel_settings
                                              : Icons.person,
                                          color: memberRole == 'admin'
                                              ? const Color(0xFF0A4D8F)
                                              : const Color(0xFF4D6880),
                                        ),
                                        title: Text(
                                          memberUid,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        subtitle: Text(
                                          '${memberRole == 'admin' ? 'Admin' : 'Empleado'} · ${active ? 'Activo' : 'Inactivo'}',
                                        ),
                                        trailing: Switch(
                                          value: active,
                                          onChanged: canToggle
                                              ? (value) => _toggleMemberActive(
                                                    context,
                                                    orgId: orgId,
                                                    adminUid: uid,
                                                    memberUid: memberUid,
                                                    active: value,
                                                  )
                                              : null,
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                              const Divider(height: 1),
                              StreamBuilder<
                                  QuerySnapshot<Map<String, dynamic>>>(
                                stream:
                                    OrganizationService.invitesStream(orgId),
                                builder: (context, inviteSnap) {
                                  final invites =
                                      inviteSnap.data?.docs ?? const [];
                                  final pending = invites
                                      .where((d) =>
                                          (d.data()['status'] as String?) ==
                                          'pending')
                                      .length;
                                  return Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Invitaciones pendientes: $pending',
                                        style: const TextStyle(
                                            color: Color(0xFF5A7388)),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
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
              const _NotificationPermissionTile(),
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
                        if (!context.mounted) return; // lifecycle safety fix
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
                  '💡 Tip: Puedes compartir tu ID o tu Code Orbit (más corto) para que otros te contacten.',
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

  Future<void> _showExpandSeatsDialog(
    BuildContext context, {
    required String orgId,
    required String adminUid,
  }) async {
    final controller = TextEditingController(text: '10');
    final additional = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ampliar cupos'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Cupos adicionales',
            hintText: 'Ejemplo: 10',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              Navigator.of(ctx).pop(parsed);
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );

    if (additional == null) return;
    if (additional <= 0) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un número mayor a 0')),
      );
      return;
    }

    try {
      await OrganizationService.expandSeats(
        orgId: orgId,
        additionalSeats: additional,
        actorUid: adminUid,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cupos ampliados en +$additional')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo ampliar cupos: $e')),
      );
    }
  }

  Future<void> _showInviteDialog(
    BuildContext context, {
    required String orgId,
    required String adminUid,
  }) async {
    final emailController = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invitar empleado'),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Correo corporativo',
            hintText: 'empleado@empresa.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(emailController.text.trim()),
            child: const Text('Crear invitación'),
          ),
        ],
      ),
    );

    final trimmed = (email ?? '').trim();
    if (trimmed.isEmpty) return;

    try {
      await OrganizationService.createInvite(
        orgId: orgId,
        adminUid: adminUid,
        email: trimmed,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invitación creada para $trimmed')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear invitación: $e')),
      );
    }
  }

  Future<void> _toggleMemberActive(
    BuildContext context, {
    required String orgId,
    required String adminUid,
    required String memberUid,
    required bool active,
  }) async {
    try {
      await OrganizationService.setMemberActive(
        orgId: orgId,
        targetUid: memberUid,
        adminUid: adminUid,
        active: active,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            active
                ? 'Miembro activado correctamente'
                : 'Miembro desactivado correctamente',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar miembro: $e')),
      );
    }
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

class _NotificationPermissionTile extends StatefulWidget {
  const _NotificationPermissionTile();

  @override
  State<_NotificationPermissionTile> createState() =>
      _NotificationPermissionTileState();
}

class _NotificationPermissionTileState
    extends State<_NotificationPermissionTile> with WidgetsBindingObserver {
  PermissionStatus _status = PermissionStatus.denied;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Recarga el estado cuando el usuario vuelve desde la config del sistema.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    final status = await Permission.notification.status;
    if (mounted)
      setState(() {
        _status = status;
        _loading = false;
      });
  }

  Future<void> _handleTap() async {
    HapticFeedback.lightImpact();
    if (_status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Las notificaciones ya están activas ✓'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_status.isPermanentlyDenied) {
      // El usuario bloqueó el permiso → abrir configuración del sistema
      final opened = await openAppSettings();
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Abre Ajustes > Aplicaciones > Orbit > Permisos'),
          ),
        );
      }
      return;
    }

    // Solicitar permiso directamente
    final result = await Permission.notification.request();
    if (mounted) setState(() => _status = result);
    if (!mounted) return;
    if (result.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notificaciones activadas correctamente ✓'),
          backgroundColor: Color(0xFF2E7D32),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permiso de notificaciones denegado'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool granted = _status.isGranted;
    return Card(
      color: const Color(0xFFFFFFFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(
          granted
              ? Icons.notifications_active
              : Icons.notifications_off_outlined,
          color: granted ? const Color(0xFFFFC46C) : Colors.grey,
        ),
        title: const Text('Notificaciones de llamada',
            style: TextStyle(color: Color(0xFF123A5B))),
        subtitle: Text(
          _loading
              ? 'Verificando permiso...'
              : granted
                  ? 'Push activas para llamadas entrantes en segundo plano.'
                  : 'Toca para activar las notificaciones push.',
          style: TextStyle(
              color: granted
                  ? const Color(0xFF4D6880)
                  : Colors.redAccent.shade200),
        ),
        trailing: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Switch(
                value: granted,
                activeColor: const Color(0xFF0A4D8F),
                onChanged: (_) => _handleTap(),
              ),
        onTap: _handleTap,
      ),
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
