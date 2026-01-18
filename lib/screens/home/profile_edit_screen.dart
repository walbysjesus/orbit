import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _email = '';
  bool _isLoading = false;
  String? _feedbackMsg;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = AuthService.getCurrentUser();
    if (!mounted) return;
    setState(() {
      _name = user?.displayName ?? '';
      _email = user?.email ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
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
                label: 'Campo nombre',
                hint: 'Ingrese su nombre',
                child: TextFormField(
                  initialValue: _name,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    labelStyle: TextStyle(color: Colors.white),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 1.2),
                  validator: (value) => value == null || value.isEmpty ? 'Ingrese su nombre' : null,
                  onSaved: (value) => _name = value ?? '',
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                label: 'Campo email',
                hint: 'Ingrese su email',
                child: TextFormField(
                  initialValue: _email,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.white),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 1.2),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Ingrese su email';
                    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    if (!emailRegex.hasMatch(value)) return 'Email inválido';
                    return null;
                  },
                  onSaved: (value) => _email = value ?? '',
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
                        title: const Text('¿Guardar cambios?'),
                        content: const Text('¿Estás seguro que deseas actualizar tu perfil?'),
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
                        _feedbackMsg = 'Perfil actualizado (solo local)';
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
