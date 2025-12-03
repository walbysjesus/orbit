import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'screens/login/login_screen.dart';
import 'screens/register_screen.dart';

void main() {
  runApp(const Orbitapp());
}

class Orbitapp extends StatelessWidget {
  const Orbitapp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ORBIT App', // Nombre de la app
      theme: ThemeData(
        primarySwatch: Colors.deepPurple, // Tema base
      ),
      initialRoute: '/', // Ruta inicial
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
      },
    );
  }
}
