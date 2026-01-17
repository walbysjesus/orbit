import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
    // Generador de IDs únicos
    final Uuid uuid = Uuid();
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController documentNumberController =
      TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  String? documentType;
  String? country;
  String? city;

  final List<String> documentTypes = [
    'Cédula',
    'Pasaporte',
    'Tarjeta de Identidad',
    'DNI',
    'Driver License',
    'National ID',
    'Residence Permit',
    'Social Security',
    'Military ID',
    'Otro',
  ];

  final List<String> countries = [
    'Colombia',
    'México',
    'Argentina',
    'Estados Unidos',
    'España',
    'Brasil',
    'Canadá',
    'Alemania',
    'Francia',
    'Italia',
    'Reino Unido',
    'Japón',
    'China',
    'India',
    'Australia',
    'Sudáfrica',
  ];

  final Map<String, List<String>> citiesByCountry = {
    'Colombia': ['Bogotá', 'Medellín', 'Cali', 'Barranquilla', 'Cartagena'],
    'México': ['Ciudad de México', 'Monterrey', 'Guadalajara', 'Cancún', 'Puebla'],
    'Argentina': ['Buenos Aires', 'Córdoba', 'Rosario', 'Mendoza', 'La Plata'],
    'Estados Unidos': ['New York', 'Los Angeles', 'Chicago', 'Miami', 'Houston'],
    'España': ['Madrid', 'Barcelona', 'Valencia', 'Sevilla', 'Zaragoza'],
    'Brasil': ['São Paulo', 'Rio de Janeiro', 'Brasília', 'Salvador', 'Fortaleza'],
    'Canadá': ['Toronto', 'Vancouver', 'Montreal', 'Calgary', 'Ottawa'],
    'Alemania': ['Berlín', 'Múnich', 'Hamburgo', 'Fráncfort', 'Colonia'],
    'Francia': ['París', 'Marsella', 'Lyon', 'Toulouse', 'Niza'],
    'Italia': ['Roma', 'Milán', 'Nápoles', 'Turín', 'Palermo'],
    'Reino Unido': ['Londres', 'Manchester', 'Birmingham', 'Liverpool', 'Edimburgo'],
    'Japón': ['Tokio', 'Osaka', 'Kioto', 'Yokohama', 'Sapporo'],
    'China': ['Pekín', 'Shanghái', 'Cantón', 'Shenzhen', 'Chengdu'],
    'India': ['Delhi', 'Bombay', 'Bangalore', 'Chennai', 'Calcuta'],
    'Australia': ['Sídney', 'Melbourne', 'Brisbane', 'Perth', 'Adelaida'],
    'Sudáfrica': ['Johannesburgo', 'Ciudad del Cabo', 'Durban', 'Pretoria', 'Port Elizabeth'],
  };

  @override
  void dispose() {
    fullNameController.dispose();
    documentNumberController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _registerUser() {
    if (_formKey.currentState!.validate()) {
      // Genera un ID único para el usuario (puedes usarlo en tu lógica real)
      final String userId = uuid.v4();
      debugPrint('ID único generado para el usuario: $userId');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Registration successful'),
          backgroundColor: Colors.green,
        ),
      );

      // Simulación de registro exitoso
      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home'); // navega a HomeScreen de forma profesional
      });
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

                _dropdownField(
                  label: 'Document Type',
                  value: documentType,
                  items: documentTypes,
                  onChanged: (value) {
                    setState(() => documentType = value);
                  },
                ),

                _inputField(
                  label: 'Document Number',
                  controller: documentNumberController,
                  keyboardType: TextInputType.number,
                ),

                _dropdownField(
                  label: 'Country',
                  value: country,
                  items: countries,
                  onChanged: (value) {
                    setState(() {
                      country = value;
                      city = null;
                    });
                  },
                ),

                _dropdownField(
                  label: 'City / State',
                  value: city,
                  items: country == null
                      ? []
                      : citiesByCountry[country!] ?? [],
                  onChanged: (value) {
                    setState(() => city = value);
                  },
                ),

                _inputField(
                  label: 'Email',
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                ),

                _inputField(
                  label: 'Password',
                  controller: passwordController,
                  obscureText: true,
                ),

                const SizedBox(height: 30),

                // BOTÓN SIGN UP FUNCIONAL
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3389FF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: _registerUser,
                  child: const Text(
                    'SIGN UP',
                    style: TextStyle(
                      fontSize: 18,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // BOTÓN IR A LOGIN
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
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

  Widget _dropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        dropdownColor: const Color(0xFF001F3F),
        style: const TextStyle(color: Colors.white),
        decoration: _inputDecoration(label),
        items: items
            .map(
              (item) => DropdownMenuItem(
                value: item,
                child: Text(item),
              ),
            )
            .toList(),
        onChanged: onChanged,
        validator: (value) =>
            value == null ? 'Required field' : null,
      ),
    );
  }

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
