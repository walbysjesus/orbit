import 'package:flutter/material.dart';
// import '../../services/auth_service.dart';

class SecurityEditScreen extends StatefulWidget {
  const SecurityEditScreen({super.key});

  @override
  State<SecurityEditScreen> createState() => _SecurityEditScreenState();
}

class _SecurityEditScreenState extends State<SecurityEditScreen> {
  final _formKey = GlobalKey<FormState>();
  String _password = '';
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String _passwordStrength = '';
  Color _strengthColor = Colors.red;
  bool _isLoading = false;
  String? _feedbackMsg;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }


  Future<void> _loadUser() async {
    // Ya no se usa orbitId, solo carga usuario si es necesario
  }


  void _checkStrength(String value) {
    if (value.length < 6) {
      _passwordStrength = 'Débil';
      _strengthColor = Colors.red;
    } else if (RegExp(r'^(?=.*[A-Z])(?=.*[0-9])').hasMatch(value)) {
      _passwordStrength = 'Fuerte';
      _strengthColor = Colors.green;
    } else {
      _passwordStrength = 'Media';
      _strengthColor = Colors.orange;
    }
    setState(() {});
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Seguridad'),
        backgroundColor: const Color(0xFF001F3F),
      ),
      backgroundColor: const Color(0xFF001F3F),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Semantics(
                label: 'Campo nueva contraseña',
                hint: 'Ingrese su nueva contraseña',
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Nueva contraseña',
                    labelStyle: const TextStyle(color: Colors.white),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white),
                      tooltip: _obscurePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 1.2),
                  obscureText: _obscurePassword,
                  validator: (value) => value == null || value.length < 6 ? 'Mínimo 6 caracteres' : null,
                  onChanged: (value) {
                    _password = value;
                    _checkStrength(value);
                  },
                  onSaved: (value) => _password = value ?? '',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Fuerza: $_passwordStrength', style: TextStyle(color: _strengthColor)),
                ],
              ),
              const SizedBox(height: 16),
              Semantics(
                label: 'Campo confirmar contraseña',
                hint: 'Repita la nueva contraseña',
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Confirmar contraseña',
                    labelStyle: const TextStyle(color: Colors.white),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: Colors.white),
                      tooltip: _obscureConfirm ? 'Mostrar contraseña' : 'Ocultar contraseña',
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 1.2),
                  obscureText: _obscureConfirm,
                  validator: (value) => value != _password ? 'Las contraseñas no coinciden' : null,
                  // onSaved innecesario, _confirmPassword eliminado
                ),
              ),
              const SizedBox(height: 32),
              if (_feedbackMsg != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_feedbackMsg!, style: const TextStyle(color: Colors.redAccent)),
                ),
              ElevatedButton.icon(
                icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                label: const Text('Guardar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isLoading ? null : () async {
                  if (_formKey.currentState?.validate() ?? false) {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('¿Guardar nueva contraseña?'),
                        content: const Text('¿Estás seguro que deseas actualizar tu contraseña?'),
                        actions: [
                          TextButton(
                            child: const Text('Cancelar'),
                            onPressed: () => Navigator.of(ctx).pop(false),
                          ),
                          TextButton(
                            child: const Text('Confirmar'),
                            onPressed: () => Navigator.of(ctx).pop(true),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      _formKey.currentState?.save();
                      setState(() {
                        _feedbackMsg = 'Contraseña actualizada (solo local)';
                      });
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
