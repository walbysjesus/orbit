import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController documentNumberController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _obscurePassword = true;

  String? documentType;
  String? country;
  String? city;

  final List<String> documentTypes = [
    'Cédula',
    'Pasaporte',
    'DNI',
    'Driver License',
    'National ID',
    'Otro',
  ];

  // ================== PAÍSES ==================
  final List<String> countries = [
    'Argentina',
    'Australia',
    'Brasil',
    'Canadá',
    'Chile',
    'China',
    'Colombia',
    'España',
    'Estados Unidos',
    'Francia',
    'Alemania',
    'India',
    'Italia',
    'Japón',
    'México',
    'Perú',
    'Reino Unido',
    'Sudáfrica',
  ];

  // ...existing code...
  final Map<String, List<String>> citiesByCountry = {
    'Argentina': [ 'Buenos Aires', 'Córdoba', 'Rosario', 'Mendoza', 'La Plata' ],
    'Australia': [ 'Sydney', 'Melbourne', 'Brisbane', 'Perth', 'Adelaide' ],
    'Brasil': [ 'São Paulo', 'Rio de Janeiro', 'Brasília', 'Salvador', 'Fortaleza' ],
    'Canadá': [ 'Toronto', 'Vancouver', 'Montreal', 'Calgary', 'Ottawa' ],
    'Chile': [ 'Santiago', 'Valparaíso', 'Concepción', 'Antofagasta', 'La Serena' ],
    'China': [ 'Beijing', 'Shanghai', 'Shenzhen', 'Guangzhou', 'Chengdu' ],
    'Colombia': [ 'Bogotá', 'Medellín', 'Cali', 'Barranquilla', 'Cartagena' ],
    'España': [ 'Madrid', 'Barcelona', 'Valencia', 'Sevilla', 'Zaragoza' ],
    'Estados Unidos': [ 'New York', 'Los Angeles', 'Chicago', 'Miami', 'Houston' ],
    'Francia': [ 'Paris', 'Marseille', 'Lyon', 'Toulouse', 'Nice' ],
    'Alemania': [ 'Berlin', 'Munich', 'Hamburg', 'Frankfurt', 'Cologne' ],
    'India': [ 'New Delhi', 'Mumbai', 'Bangalore', 'Chennai', 'Hyderabad' ],
    'Italia': [ 'Rome', 'Milan', 'Naples', 'Turin', 'Florence' ],
    'Japón': [ 'Tokyo', 'Osaka', 'Kyoto', 'Yokohama', 'Sapporo' ],
    'México': [ 'Ciudad de México', 'Monterrey', 'Guadalajara', 'Puebla', 'Cancún' ],
    'Perú': [ 'Lima', 'Arequipa', 'Trujillo', 'Cusco', 'Piura' ],
    'Reino Unido': [ 'London', 'Manchester', 'Birmingham', 'Liverpool', 'Edinburgh' ],
    'Sudáfrica': [ 'Johannesburg', 'Cape Town', 'Durban', 'Pretoria', 'Port Elizabeth' ],
  };

  @override
  void dispose() {
    fullNameController.dispose();
    documentNumberController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await AuthService.register(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        fullName: fullNameController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registro exitoso'),
          backgroundColor: Colors.green,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'CREATE ACCOUNT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 30),

                _inputField(
                  label: 'Full Name',
                  controller: fullNameController,
                ),

                  // ...continúan los campos del formulario...

                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Password').copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white,
                        ),
                        tooltip: _obscurePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Required field' : null,
                  ),
                ),

                const SizedBox(height: 30),

                _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF3389FF),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: _registerUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3389FF),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'SIGN UP',
                          style: TextStyle(
                            fontSize: 18,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),

                const SizedBox(height: 20),

                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Already have an account? Log In',
                    style: TextStyle(
                      color: Colors.white70,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================== INPUTS ==================

  Widget _inputField({
    required String label,
    required TextEditingController controller,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: _inputDecoration(label),
        validator: (value) =>
            value == null || value.isEmpty ? 'Required field' : null,
      ),
    );
  }

  // Widget _dropdownField({ ... }) removed (unused)

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.white38),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.white),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}
