import 'package:flutter/material.dart';
import 'package:orbit/login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          /// Fondo espacial
          Positioned.fill(
            child: Image.asset(
              'assets/images/background_space.jpg',
              fit: BoxFit.cover,
            ),
          ),

          /// Contenido centrado
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                /// Texto WELCOME TO
                Text(
                  'WELCOME TO',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 26,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 3,
                  ),
                ),

                const SizedBox(height: 10),

                /// Texto ORBIT
                Text(
                  'ORBIT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                  ),
                ),

                const SizedBox(height: 30),

                /// Esfera azul (tu logo actual)
                Image.asset(
                  'assets/images/logo_orbit.jpg',
                  width: 220,
                  height: 220,
                ),

                const SizedBox(height: 40),

                /// Botón Log In
                SizedBox(
                  width: 220,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                    },
                    child: const Text(
                      'Log In',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                /// Botón Create Account
                SizedBox(
                  width: 220,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RegisterScreen()),
                      );
                    },
                    child: const Text(
                      'Create Account',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
