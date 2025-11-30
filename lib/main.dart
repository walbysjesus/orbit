import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'login/login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
      },
    );
  }
}
