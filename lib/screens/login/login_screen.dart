import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool loading = false;

  Future<void> loginUser() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showMessage("Completa todos los campos");
      return;
    }

    setState(() => loading = true);

    try {
      // LOGIN CON FIREBASE
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // LOGIN CON API INTERNA DE ORBIT
      await loginOrbitAPI(email, password);

      showMessage("Inicio exitoso 🚀");

      // IR A PANTALLA PRINCIPAL
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      showMessage(firebaseError(e.code));
    } catch (e) {
      showMessage("Error inesperado: $e");
    }

    setState(() => loading = false);
  }

  // SIMULACIÓN API ORBIT (puedes conectar tu servidor aquí)
  Future<void> loginOrbitAPI(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return; // Aquí iría tu llamada HTTP POST
  }

  String firebaseError(String code) {
    switch (code) {
      case "invalid-email":
        return "Correo inválido";
      case "user-not-found":
        return "Usuario no existe";
      case "wrong-password":
        return "Contraseña incorrecta";
      default:
        return "Error: $code";
    }
  }

  void showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff020617), // NEGRO ESPACIAL ORBIT
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                "Bienvenido a",
                style: TextStyle(color: Colors.white70, fontSize: 20),
              ),
              const Text(
                "ORBIT",
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 35),

              // CORREO
              field(
                controller: emailController,
                label: "Correo electrónico",
                icon: Icons.email_outlined,
              ),

              const SizedBox(height: 20),

              // CONTRASEÑA
              field(
                controller: passwordController,
                label: "Contraseña",
                icon: Icons.lock_outline,
                obscure: true,
              ),

              const SizedBox(height: 35),

              // BOTÓN LOGIN
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : loginUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Iniciar sesión",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
