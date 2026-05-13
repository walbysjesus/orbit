import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/security_service.dart';
import '../../services/mfa_service.dart';
import '../../models/orbit_user.dart';

/// Pantalla completa de perfil y seguridad con MFA y verificación de email
class ProfileSecurityScreen extends StatefulWidget {
  final OrbitUser? orbitUser;

  const ProfileSecurityScreen({super.key, this.orbitUser});

  @override
  State<ProfileSecurityScreen> createState() => _ProfileSecurityScreenState();
}

class _ProfileSecurityScreenState extends State<ProfileSecurityScreen> {
  late OrbitUser _user;
  bool _emailVerified = false;
  bool _mfaEnabled = false;
  bool _isLoading = false;

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirm = true;
  String _passwordStrength = '';
  Color _strengthColor = Colors.red;

  @override
  void initState() {
    super.initState();
    _user = widget.orbitUser ??
        OrbitUser(
          uid: FirebaseAuth.instance.currentUser?.uid ?? '',
          email: FirebaseAuth.instance.currentUser?.email,
        );
    _loadSecurityStatus();
  }

  Future<void> _loadSecurityStatus() async {
    if (!mounted) return; // lifecycle safety fix
    setState(() => _isLoading = true);

    try {
      final emailVerified = await SecurityService.isEmailVerified();
      final mfaEnabled = await MfaService.isMfaEnabled();

      if (!mounted) return; // lifecycle safety fix

      setState(() {
        _emailVerified = emailVerified;
        _mfaEnabled = mfaEnabled;
      });
    } catch (e) {
      _showError('Error cargando estado: $e');
    } finally {
      if (!mounted) return; // lifecycle safety fix
      setState(() => _isLoading = false);
    }
  }

  void _checkPasswordStrength(String value) {
    if (value.length < 8) {
      _passwordStrength = 'Débil';
      _strengthColor = Colors.red;
    } else if (RegExp(r'^(?=.*[A-Z])(?=.*[0-9])(?=.*[!@#$&*~%^?¿.,;:_\-])')
        .hasMatch(value)) {
      _passwordStrength = 'Fuerte';
      _strengthColor = Colors.green;
    } else if (RegExp(r'^(?=.*[A-Z])(?=.*[0-9])').hasMatch(value)) {
      _passwordStrength = 'Media';
      _strengthColor = Colors.orange;
    } else {
      _passwordStrength = 'Débil';
      _strengthColor = Colors.red;
    }
    setState(() {});
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text.isEmpty ||
        _currentPasswordController.text.isEmpty) {
      _showError('Completa todos los campos');
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showError('Las contraseñas no coinciden');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await SecurityService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (!mounted) return; // lifecycle safety fix

      _showSuccess(
        '✓ Contraseña actualizada. Por favor, inicia sesión nuevamente.',
      );

      // Limpiar formulario
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      await Future.delayed(const Duration(seconds: 2));
      if (!context.mounted) return; // lifecycle safety fix
      Navigator.of(context).pop();
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (!mounted) return; // lifecycle safety fix
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendEmailVerification() async {
    setState(() => _isLoading = true);

    try {
      await SecurityService.sendEmailVerification();
      if (!mounted) return; // lifecycle safety fix
      _showSuccess(
        '✓ Email de verificación enviado. Revisa tu bandeja de entrada.',
      );
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (!mounted) return; // lifecycle safety fix
      setState(() => _isLoading = false);
    }
  }

  Future<void> _setupMfa() async {
    // Navegar a pantalla de setup MFA
    showDialog(
      context: context,
      builder: (ctx) => const MfaSetupDialog(),
    ).then((_) => _loadSecurityStatus());
  }

  void _showSuccess(String msg) {
    if (!mounted) return; // lifecycle safety fix
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return; // lifecycle safety fix
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil y Seguridad'),
        backgroundColor: const Color(0xFF0A4D8F),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF3F8FD),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Estado de Seguridad
                  _buildSecurityStatusCard(),
                  const SizedBox(height: 24),

                  // Verificación de Email
                  _buildEmailVerificationSection(),
                  const SizedBox(height: 24),

                  // Autenticación Multi-Factor
                  _buildMfaSection(),
                  const SizedBox(height: 24),

                  // Cambiar Contraseña
                  _buildPasswordChangeSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildSecurityStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE9F4FF), Color(0xFFD9EEFF)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBCD8EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estado de Seguridad',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0A4D8F),
            ),
          ),
          const SizedBox(height: 16),
          _buildStatusItem(
            'Email Verificado',
            _emailVerified,
            Icons.email,
          ),
          const SizedBox(height: 12),
          _buildStatusItem(
            'Autenticación de Dos Factores',
            _mfaEnabled,
            Icons.security,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, bool isEnabled, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: isEnabled ? Colors.green : Colors.orange,
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0A4D8F),
                ),
              ),
              Text(
                isEnabled ? 'Habilitado' : 'Deshabilitado',
                style: TextStyle(
                  fontSize: 12,
                  color: isEnabled ? Colors.green : const Color(0xFF5A7388),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmailVerificationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBCD8EE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.email, color: Color(0xFF0A4D8F), size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Verificación de Email',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A4D8F),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _emailVerified
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _emailVerified ? '✓ Verificado' : '⚠ Pendiente',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _emailVerified ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Tu email es: ${_user.email ?? 'No configurado'}',
            style: const TextStyle(
              color: Color(0xFF5A7388),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          if (!_emailVerified)
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _sendEmailVerification,
              icon: const Icon(Icons.mail_outline),
              label: const Text('Enviar Email de Verificación'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMfaSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBCD8EE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security, color: Color(0xFF0A4D8F), size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Autenticación de Dos Factores',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A4D8F),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _mfaEnabled
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFF3E5F5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _mfaEnabled ? '✓ Activa' : 'Inactiva',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _mfaEnabled ? Colors.green : const Color(0xFF8A4184),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Requiere un código adicional al iniciar sesión desde un nuevo dispositivo.',
            style: TextStyle(
              color: Color(0xFF5A7388),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _setupMfa,
            icon: Icon(_mfaEnabled ? Icons.edit : Icons.add),
            label: Text(
              _mfaEnabled ? 'Editar Autenticación' : 'Habilitar Autenticación',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A4D8F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordChangeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBCD8EE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lock, color: Color(0xFF0A4D8F), size: 24),
              SizedBox(width: 12),
              Text(
                'Cambiar Contraseña',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A4D8F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Contraseña actual
          _buildPasswordField(
            label: 'Contraseña Actual',
            controller: _currentPasswordController,
            obscure: _obscureCurrentPassword,
            onToggleObscure: () => setState(
              () => _obscureCurrentPassword = !_obscureCurrentPassword,
            ),
          ),
          const SizedBox(height: 12),
          // Nueva contraseña
          _buildPasswordField(
            label: 'Nueva Contraseña',
            controller: _newPasswordController,
            obscure: _obscureNewPassword,
            onToggleObscure: () => setState(
              () => _obscureNewPassword = !_obscureNewPassword,
            ),
            onChanged: _checkPasswordStrength,
            hint: 'Mín. 8 caracteres, mayúscula, número, carácter especial',
          ),
          if (_newPasswordController.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Fuerza: $_passwordStrength',
                  style: TextStyle(
                    color: _strengthColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LinearProgressIndicator(
                    value: _passwordStrength == 'Débil'
                        ? 0.33
                        : _passwordStrength == 'Media'
                            ? 0.66
                            : 1.0,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(_strengthColor),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          // Confirmar contraseña
          _buildPasswordField(
            label: 'Confirmar Contraseña',
            controller: _confirmPasswordController,
            obscure: _obscureConfirm,
            onToggleObscure: () => setState(
              () => _obscureConfirm = !_obscureConfirm,
            ),
          ),
          const SizedBox(height: 24),
          // Botones
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          _currentPasswordController.clear();
                          _newPasswordController.clear();
                          _confirmPasswordController.clear();
                        },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF8FD5FF)),
                  ),
                  child: const Text(
                    'Limpiar',
                    style: TextStyle(color: Color(0xFF0A4D8F)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _changePassword,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.lock_reset),
                  label: Text(
                      _isLoading ? 'Actualizando...' : 'Cambiar Contraseña'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A4D8F),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggleObscure,
    ValueChanged<String>? onChanged,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5A7388),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFFC0C0C0),
              fontSize: 12,
            ),
            prefixIcon: const Icon(Icons.lock, color: Color(0xFF8FD5FF)),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF8FD5FF),
              ),
              onPressed: onToggleObscure,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFBCD8EE)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFBCD8EE)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0A4D8F), width: 2),
            ),
            filled: true,
            fillColor: const Color(0xFFFAFBFC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }
}

/// Diálogo para setup MFA
class MfaSetupDialog extends StatefulWidget {
  const MfaSetupDialog({super.key});

  @override
  State<MfaSetupDialog> createState() => _MfaSetupDialogState();
}

class _MfaSetupDialogState extends State<MfaSetupDialog> {
  String _qrCode = '';
  String _secret = '';
  bool _isLoading = true;
  final _totpCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _generateMfaSecret();
  }

  Future<void> _generateMfaSecret() async {
    try {
      final result = await MfaService.generateTotpSecret();
      if (!mounted) return;
      setState(() {
        _qrCode = result['qrCode']!;
        _secret = result['secret']!;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmMfa() async {
    final code = _totpCodeController.text.trim();
    if (code.isEmpty || code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un código de 6 dígitos')),
      );
      return;
    }

    try {
      await MfaService.confirmTotpSetup(totpCode: code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Autenticación de dos factores habilitada'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _totpCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configurar Autenticación de Dos Factores'),
      content: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Escanea este código QR con Google Authenticator, Authy o Microsoft Authenticator:',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Image.network(
                    _qrCode,
                    width: 200,
                    height: 200,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 200,
                        height: 200,
                        color: Colors.grey[300],
                        child: Center(
                          child: Text('Error cargando QR: $error'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'O ingresa esta clave manualmente:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _secret,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Ingresa el código de 6 dígitos de tu aplicador:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _totpCodeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                    decoration: InputDecoration(
                      hintText: '000000',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _confirmMfa,
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
