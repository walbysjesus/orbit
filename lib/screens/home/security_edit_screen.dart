import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/security_service.dart';

class SecurityEditScreen extends StatefulWidget {
  const SecurityEditScreen({super.key});

  @override
  State<SecurityEditScreen> createState() => _SecurityEditScreenState();
}

class _SecurityEditScreenState extends State<SecurityEditScreen> {
  // ─── estado general ───────────────────────────────────
  User? _user;
  bool _emailVerified = false;
  List<Map<String, dynamic>> _securityLogs = [];
  bool _loadingLogs = false;

  // ─── cambio de contraseña ────────────────────────────
  final _pwFormKey = GlobalKey<FormState>();
  final _currentPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String _pwStrength = '';
  Color _pwStrengthColor = Colors.red;
  bool _savingPw = false;

  // ─── verificación email ──────────────────────────────
  bool _sendingVerification = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _currentPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    _user = FirebaseAuth.instance.currentUser;
    await _user?.reload();
    if (!mounted) return; // lifecycle safety fix
    _user = FirebaseAuth.instance.currentUser;
    if (mounted) {
      setState(() => _emailVerified = _user?.emailVerified ?? false);
    }
    await _loadLogs();
  }

  Future<void> _loadLogs() async {
    if (_user == null) return;
    if (!mounted) return; // lifecycle safety fix
    setState(() => _loadingLogs = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('securityLogs')
          .where('userId', isEqualTo: _user!.uid)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();
      if (mounted) {
        setState(() {
          _securityLogs = snap.docs.map((d) => d.data()).toList();
        });
      }
    } catch (_) {
      // sin permisos o sin conexión: lista vacía
    } finally {
      if (mounted) setState(() => _loadingLogs = false);
    }
  }

  void _evalStrength(String value) {
    String label;
    Color color;
    if (value.length < 6) {
      label = 'Débil';
      color = Colors.red;
    } else if (value.length >= 12 &&
        RegExp(r'[A-Z]').hasMatch(value) &&
        RegExp(r'[0-9]').hasMatch(value) &&
        RegExp(r'[!@#\$%^&*]').hasMatch(value)) {
      label = 'Muy fuerte';
      color = const Color(0xFF00C896);
    } else if (RegExp(r'[A-Z]').hasMatch(value) &&
        RegExp(r'[0-9]').hasMatch(value)) {
      label = 'Fuerte';
      color = Colors.green;
    } else {
      label = 'Media';
      color = Colors.orange;
    }
    setState(() {
      _pwStrength = label;
      _pwStrengthColor = color;
    });
  }

  Future<void> _changePassword() async {
    if (!(_pwFormKey.currentState?.validate() ?? false)) return;
    final confirm = await _confirm(
      '¿Cambiar contraseña?',
      'Necesitarás tu contraseña actual para confirmar.',
    );
    if (!confirm) return;

    setState(() => _savingPw = true);
    try {
      await SecurityService.changePassword(
        currentPassword: _currentPwCtrl.text.trim(),
        newPassword: _newPwCtrl.text.trim(),
      );
      if (!mounted) return;
      _currentPwCtrl.clear();
      _newPwCtrl.clear();
      _confirmPwCtrl.clear();
      setState(() => _pwStrength = '');
      _snack('Contraseña actualizada correctamente', success: true);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceAll('Exception:', '').trim());
    } finally {
      if (mounted) setState(() => _savingPw = false);
    }
  }

  Future<void> _sendVerification() async {
    setState(() => _sendingVerification = true);
    try {
      await SecurityService.sendEmailVerification();
      if (!mounted) return;
      _snack('Correo de verificación enviado a ${_user?.email}', success: true);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceAll('Exception:', '').trim());
    } finally {
      if (mounted) setState(() => _sendingVerification = false);
    }
  }

  Future<bool> _confirm(String title, String body) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          FilledButton(
            child: const Text('Confirmar'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return; // lifecycle safety fix
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? const Color(0xFF00C896) : Colors.redAccent,
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8FD),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A4D8F),
        foregroundColor: Colors.white,
        title: const Text('Seguridad',
            style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadState,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionHeader(Icons.lock_outline, 'Contraseña'),
            _card(_passwordSection()),
            const SizedBox(height: 16),
            _sectionHeader(Icons.verified_outlined, 'Verificación de email'),
            _card(_emailVerificationSection()),
            const SizedBox(height: 16),
            _sectionHeader(Icons.history_outlined, 'Actividad reciente'),
            _card(_activitySection()),
            const SizedBox(height: 16),
            _sectionHeader(Icons.info_outline, 'Información de sesión'),
            _card(_sessionInfoSection()),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF0A4D8F)),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF0A4D8F),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }

  // ── SECCIÓN CONTRASEÑA ────────────────────────────────

  Widget _passwordSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _pwFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _pwField(
              controller: _currentPwCtrl,
              label: 'Contraseña actual',
              obscure: _obscureCurrent,
              onToggle: () =>
                  setState(() => _obscureCurrent = !_obscureCurrent),
              validator: (v) => (v == null || v.isEmpty)
                  ? 'Ingresa tu contraseña actual'
                  : null,
            ),
            const SizedBox(height: 12),
            _pwField(
              controller: _newPwCtrl,
              label: 'Nueva contraseña',
              obscure: _obscureNew,
              onToggle: () => setState(() => _obscureNew = !_obscureNew),
              onChanged: _evalStrength,
              validator: (v) {
                if (v == null || v.length < 8) return 'Mínimo 8 caracteres';
                if (!RegExp(r'[A-Z]').hasMatch(v))
                  return 'Incluye al menos una mayúscula';
                if (!RegExp(r'[0-9]').hasMatch(v))
                  return 'Incluye al menos un número';
                return null;
              },
            ),
            if (_pwStrength.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _pwStrengthColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Contraseña $_pwStrength',
                    style: TextStyle(color: _pwStrengthColor, fontSize: 12),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            _pwField(
              controller: _confirmPwCtrl,
              label: 'Confirmar nueva contraseña',
              obscure: _obscureConfirm,
              onToggle: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              validator: (v) =>
                  v != _newPwCtrl.text ? 'Las contraseñas no coinciden' : null,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _savingPw ? null : _changePassword,
                icon: _savingPw
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.lock_reset),
                label: const Text('Actualizar contraseña'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0A4D8F),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mínimo 8 caracteres · Al menos 1 mayúscula y 1 número.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pwField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF8FCFF),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCDD8E4)),
        ),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
              color: const Color(0xFF5F7890)),
          onPressed: onToggle,
        ),
      ),
    );
  }

  // ── SECCIÓN EMAIL VERIFICACIÓN ────────────────────────

  Widget _emailVerificationSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            _emailVerified ? Icons.verified : Icons.warning_amber_rounded,
            color: _emailVerified
                ? const Color(0xFF00C896)
                : const Color(0xFFFFB300),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _user?.email ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF16324F),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _emailVerified
                      ? 'Email verificado'
                      : 'Email no verificado — revisa tu bandeja',
                  style: TextStyle(
                    fontSize: 12,
                    color: _emailVerified
                        ? Colors.grey.shade600
                        : const Color(0xFFFFB300),
                  ),
                ),
              ],
            ),
          ),
          if (!_emailVerified)
            TextButton(
              onPressed: _sendingVerification ? null : _sendVerification,
              child: _sendingVerification
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Verificar'),
            ),
          if (_emailVerified)
            TextButton(
              onPressed: _loadState,
              child: const Text('Actualizar'),
            ),
        ],
      ),
    );
  }

  // ── SECCIÓN ACTIVIDAD RECIENTE ────────────────────────

  Widget _activitySection() {
    if (_loadingLogs) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_securityLogs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text(
            'Sin actividad registrada',
            style: TextStyle(color: Color(0xFF6D7F92)),
          ),
        ),
      );
    }
    return Column(
      children: _securityLogs.map((log) {
        final ts = (log['timestamp'] as Timestamp?)?.toDate();
        final type = log['eventType'] as String? ?? 'evento';
        final label = _logLabel(type);
        final icon = _logIcon(type);
        final color = _logColor(type);
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 18),
          ),
          title: Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Color(0xFF16324F))),
          subtitle: ts != null
              ? Text(
                  '${ts.day}/${ts.month}/${ts.year}  ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}',
                  style:
                      const TextStyle(color: Color(0xFF6D7F92), fontSize: 12),
                )
              : null,
        );
      }).toList(),
    );
  }

  String _logLabel(String type) {
    switch (type) {
      case 'password_changed':
        return 'Contraseña cambiada';
      case 'email_verification_sent':
        return 'Verificación enviada';
      case 'logout':
        return 'Cierre de sesión';
      case 'failed_login':
        return 'Intento fallido de acceso';
      case 'login':
        return 'Inicio de sesión';
      default:
        return type.replaceAll('_', ' ');
    }
  }

  IconData _logIcon(String type) {
    switch (type) {
      case 'password_changed':
        return Icons.lock_reset;
      case 'email_verification_sent':
        return Icons.email_outlined;
      case 'logout':
        return Icons.logout;
      case 'failed_login':
        return Icons.warning_amber;
      default:
        return Icons.security;
    }
  }

  Color _logColor(String type) {
    switch (type) {
      case 'failed_login':
        return Colors.red;
      case 'password_changed':
        return const Color(0xFF0A4D8F);
      case 'logout':
        return Colors.orange;
      default:
        return const Color(0xFF00C896);
    }
  }

  // ── SECCIÓN INFO SESIÓN ───────────────────────────────

  Widget _sessionInfoSection() {
    final uid = _user?.uid ?? '—';
    final email = _user?.email ?? '—';
    final creation = _user?.metadata.creationTime;
    final lastSign = _user?.metadata.lastSignInTime;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _infoRow('UID', uid, copyable: true),
          const Divider(height: 20),
          _infoRow('Email', email),
          const Divider(height: 20),
          _infoRow(
            'Cuenta creada',
            creation != null
                ? '${creation.day}/${creation.month}/${creation.year}'
                : '—',
          ),
          const Divider(height: 20),
          _infoRow(
            'Último acceso',
            lastSign != null
                ? '${lastSign.day}/${lastSign.month}/${lastSign.year}  ${lastSign.hour.toString().padLeft(2, '0')}:${lastSign.minute.toString().padLeft(2, '0')}'
                : '—',
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool copyable = false}) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF6D7F92), fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
                color: Color(0xFF16324F),
                fontWeight: FontWeight.w600,
                fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (copyable)
          IconButton(
            icon: const Icon(Icons.copy, size: 16, color: Color(0xFF5F7890)),
            tooltip: 'Copiar',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              _snack('Copiado', success: true);
            },
          ),
      ],
    );
  }
}
