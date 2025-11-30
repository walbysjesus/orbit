import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool agreeTerms = false;
  bool isLoginMode = false; // false = Sign Up, true = Log In

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F2F),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // TITULO ORBIT
                Text(
                  "Orbit",
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(height: 25),

                // LOGIN / SIGNIN Tabs
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildTabButton("Sign Up", !isLoginMode),
                      _buildTabButton("Sign In", isLoginMode),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // CAMPOS
                if (!isLoginMode) ...[
                  _inputField("Nombre y apellido"),
                  _inputField("País"),
                  _inputField("Ciudad"),
                  _inputField("Documento"),
                  _inputField("E-mail"),
                  _inputField("Password", obscure: true),
                ] else ...[
                  _inputField("E-mail"),
                  _inputField("Password", obscure: true),
                ],

                const SizedBox(height: 15),

                // TERMS & CONDITIONS - Solo Sign Up
                if (!isLoginMode)
                  Row(
                    children: [
                      Checkbox(
                        value: agreeTerms,
                        onChanged: (v) {
                          setState(() {
                            agreeTerms = v!;
                          });
                        },
                        activeColor: Colors.blueAccent,
                      ),
                      const Expanded(
                        child: Text(
                          "Agree with terms & conditions",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 30),

                // BOTON PRINCIPAL
                GestureDetector(
                  onTap: () {
                    // ACCIÓN DEL BOTÓN
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        isLoginMode ? "Log In" : "Sign Up",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // YA ESTOY REGISTRADO / CREAR CUENTA
                GestureDetector(
                  onTap: () {
                    setState(() {
                      isLoginMode = !isLoginMode;
                    });
                  },
                  child: Text(
                    isLoginMode
                        ? "¿No tienes cuenta? Crear cuenta"
                        : "Ya estoy registrado",
                    style: const TextStyle(
                      color: Colors.white70,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // TAB BUTTON
  Widget _buildTabButton(String text, bool active) {
    return GestureDetector(
      onTap: () {
        setState(() {
          isLoginMode = (text == "Sign In");
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.blueAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: active ? Colors.white : Colors.white60,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // INPUT FIELD
  Widget _inputField(String label, {bool obscure = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: TextField(
        obscureText: obscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white24),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.blueAccent),
          ),
        ),
      ),
    );
  }
}
