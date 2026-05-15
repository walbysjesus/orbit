import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();

  // ─── controladores ────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();

  // ─── estado ───────────────────────────────────────────
  String _email = '';
  String _orbitNumber = '';
  String _uid = '';
  bool _emailVerified = false;
  String? _documentType;
  String _documentNumber = '';
  bool _loading = true;
  bool _saving = false;

  static const _docTypes = ['CC', 'CE', 'TI', 'Pasaporte', 'NIT', 'Otro'];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _bioCtrl.dispose();
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return; // lifecycle safety fix
    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await user.reload();
      if (!mounted) return; // lifecycle safety fix
      final fresh = FirebaseAuth.instance.currentUser!;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(fresh.uid)
          .get();
      if (!mounted) return; // lifecycle safety fix
      final data = doc.data() ?? {};

      if (mounted) {
        setState(() {
          _uid = fresh.uid;
          _email = fresh.email ?? '';
          _emailVerified = fresh.emailVerified;
          _orbitNumber = data['orbitNumber'] as String? ?? '';
          _nameCtrl.text =
              data['fullName'] as String? ?? fresh.displayName ?? '';
          _phoneCtrl.text = data['phoneNumber'] as String? ?? '';
          _bioCtrl.text = data['bio'] as String? ?? '';
          _cityCtrl.text = data['city'] as String? ?? '';
          _countryCtrl.text = data['country'] as String? ?? '';
          _documentType = data['documentType'] as String?;
          _documentNumber = data['documentNumber'] as String? ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        _snack(
            'Error al cargar perfil: ${e.toString().replaceAll("Exception:", "").trim()}');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState?.save();

    final confirm = await _confirm(
      '¿Guardar cambios?',
      'Los cambios se sincronizarán con tu cuenta Orbit.',
    );
    if (!confirm) return;

    if (!mounted) return; // lifecycle safety fix
    setState(() => _saving = true);
    try {
      final user = AuthService.getCurrentUser();
      if (user == null) throw Exception('Usuario no autenticado');

      // Actualizar display name en Firebase Auth
      await user.updateDisplayName(_nameCtrl.text.trim());
      if (!mounted) return; // lifecycle safety fix

      // Actualizar datos en Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'fullName': _nameCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'country': _countryCtrl.text.trim(),
        if (_documentType != null) 'documentType': _documentType,
        'documentNumber': _documentNumber.trim(),
      });

      if (!mounted) return;
      _snack('Perfil actualizado correctamente', success: true);

      // Refrescar datos mostrados
      await _loadProfile();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceAll('Exception:', '').trim());
    } finally {
      if (mounted) setState(() => _saving = false);
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
            child: const Text('Guardar'),
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
        title:
            const Text('Perfil', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (!_saving)
            TextButton(
              onPressed: _loading ? null : _saveProfile,
              child: const Text(
                'Guardar',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Avatar + identidad ──────────────────
                  _avatarHeader(),
                  const SizedBox(height: 20),

                  // ── Datos personales ────────────────────
                  _sectionHeader(Icons.person_outline, 'Datos personales'),
                  _card(_personalDataSection()),
                  const SizedBox(height: 16),

                  // ── Documento ──────────────────────────
                  _sectionHeader(Icons.badge_outlined, 'Documento'),
                  _card(_documentSection()),
                  const SizedBox(height: 16),

                  // ── Ubicación ──────────────────────────
                  _sectionHeader(Icons.location_on_outlined, 'Ubicación'),
                  _card(_locationSection()),
                  const SizedBox(height: 16),

                  // ── Información de cuenta ──────────────
                  _sectionHeader(Icons.account_circle_outlined, 'Cuenta Orbit'),
                  _card(_accountInfoSection()),
                  const SizedBox(height: 24),

                  // ── Botón guardar bottom ────────────────
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (_saving || _loading) ? null : _saveProfile,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Guardar cambios'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0A4D8F),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
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

  // ── AVATAR HEADER ─────────────────────────────────────

  Widget _avatarHeader() {
    final initials = _nameCtrl.text.trim().isNotEmpty
        ? _nameCtrl.text
            .trim()
            .split(' ')
            .map((w) => w.isNotEmpty ? w[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : '?';

    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: const Color(0xFF0A4D8F),
            child: Text(
              initials,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _nameCtrl.text.trim().isEmpty
                ? 'Sin nombre'
                : _nameCtrl.text.trim(),
            style: const TextStyle(
              color: Color(0xFF16324F),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _email,
                style: const TextStyle(color: Color(0xFF6D7F92), fontSize: 13),
              ),
              const SizedBox(width: 6),
              Icon(
                _emailVerified ? Icons.verified : Icons.warning_amber_rounded,
                size: 16,
                color: _emailVerified
                    ? const Color(0xFF00C896)
                    : const Color(0xFFFFB300),
              ),
            ],
          ),
          if (_orbitNumber.isNotEmpty) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: _orbitNumber));
                _snack('Orbit ID copiado', success: true);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F0FA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tag, size: 14, color: Color(0xFF0A4D8F)),
                    const SizedBox(width: 4),
                    Text(
                      _orbitNumber,
                      style: const TextStyle(
                        color: Color(0xFF0A4D8F),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.copy, size: 13, color: Color(0xFF5F7890)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── DATOS PERSONALES ──────────────────────────────────

  Widget _personalDataSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _field(
              controller: _nameCtrl,
              label: 'Nombre completo',
              icon: Icons.person_outline,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
            ),
            const SizedBox(height: 12),
            _fieldReadOnly(
              value: _email,
              label: 'Correo electrónico',
              icon: Icons.email_outlined,
              hint: 'El email se gestiona en Seguridad',
            ),
            const SizedBox(height: 12),
            _field(
              controller: _phoneCtrl,
              label: 'Teléfono',
              icon: Icons.phone_outlined,
              inputType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _field(
              controller: _bioCtrl,
              label: 'Biografía',
              icon: Icons.notes_outlined,
              maxLines: 3,
              maxLength: 160,
              hint: 'Cuéntanos algo sobre ti...',
            ),
          ],
        ),
      ),
    );
  }

  // ── DOCUMENTO ─────────────────────────────────────────

  Widget _documentSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue:
                _docTypes.contains(_documentType) ? _documentType : null,
            decoration: InputDecoration(
              labelText: 'Tipo de documento',
              prefixIcon:
                  const Icon(Icons.badge_outlined, color: Color(0xFF5F7890)),
              filled: true,
              fillColor: const Color(0xFFF8FCFF),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCDD8E4)),
              ),
            ),
            items: _docTypes
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => _documentType = v),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _documentNumber,
            decoration: InputDecoration(
              labelText: 'Número de documento',
              prefixIcon:
                  const Icon(Icons.numbers_outlined, color: Color(0xFF5F7890)),
              filled: true,
              fillColor: const Color(0xFFF8FCFF),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCDD8E4)),
              ),
            ),
            onChanged: (v) => _documentNumber = v,
          ),
        ],
      ),
    );
  }

  // ── UBICACIÓN ─────────────────────────────────────────

  Widget _locationSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _field(
            controller: _cityCtrl,
            label: 'Ciudad',
            icon: Icons.location_city_outlined,
          ),
          const SizedBox(height: 12),
          _field(
            controller: _countryCtrl,
            label: 'País',
            icon: Icons.public_outlined,
          ),
        ],
      ),
    );
  }

  // ── INFO CUENTA ───────────────────────────────────────

  Widget _accountInfoSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _infoRow(
            'Orbit ID',
            _orbitNumber.isEmpty ? 'Sin asignar' : _orbitNumber,
            copyable: _orbitNumber.isNotEmpty,
          ),
          const Divider(height: 20),
          _infoRow(
            'UID interno',
            _uid,
            copyable: true,
            truncate: true,
          ),
          const Divider(height: 20),
          _infoRow(
            'Email verificado',
            _emailVerified ? 'Sí' : 'No',
            valueColor: _emailVerified
                ? const Color(0xFF00C896)
                : const Color(0xFFFFB300),
          ),
        ],
      ),
    );
  }

  // ── HELPERS UI ────────────────────────────────────────

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    int? maxLength,
    TextInputType? inputType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: inputType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF5F7890)),
        filled: true,
        fillColor: const Color(0xFFF8FCFF),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCDD8E4)),
        ),
      ),
    );
  }

  Widget _fieldReadOnly({
    required String value,
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return TextFormField(
      initialValue: value,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF5F7890)),
        filled: true,
        fillColor: const Color(0xFFF0F4F8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCDD8E4)),
        ),
        suffixIcon:
            const Icon(Icons.lock_outline, size: 16, color: Color(0xFFADBCC9)),
      ),
    );
  }

  Widget _infoRow(
    String label,
    String value, {
    bool copyable = false,
    bool truncate = false,
    Color? valueColor,
  }) {
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
            style: TextStyle(
              color: valueColor ?? const Color(0xFF16324F),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            overflow: truncate ? TextOverflow.ellipsis : TextOverflow.visible,
            maxLines: truncate ? 1 : null,
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
