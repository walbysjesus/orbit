import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/config/config.dart';
import 'package:orbit/services/subscription_service.dart';

import 'screens/auth/welcome_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/settings_screen.dart';

import 'services/auth_service.dart';
import 'services/fcm_service.dart';
import 'services/remote_config_service.dart';

/// Punto de entrada principal de la app Orbit.
/// Inicializa Firebase y FCM (notificaciones push) con control de errores automático.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  validateProductionSecurityConfig();
  await initializeFirebase();
  await _initializeAppCheck();
  // Inicializar FCM (notificaciones push) con manejo de errores
  await FCMService.initialize();
  // Inicializar Remote Config para feature flags y promociones
  await RemoteConfigService().initialize();
  // Inicialización de suscripción (datos locales / remoto)
  await subscriptionService.upgradeTo(SubscriptionLevel.free);
  final loggedIn = await AuthService.isLoggedIn();
  runApp(MyApp(isLoggedIn: loggedIn));
}

Future<void> _initializeAppCheck() async {
  // Web requiere webProvider (clave reCAPTCHA). Se evita romper entornos sin configurar.
  if (kIsWeb) {
    debugPrint(
        'App Check web no configurado: se omite activacion en este build');
    return;
  }

  // En desarrollo local se omite App Check para evitar bloqueos 403
  // cuando la API/proveedor aun no estan configurados en Firebase.
  if (kDebugMode) {
    debugPrint('App Check desactivado en debug');
    return;
  }

  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.appAttest,
    );
  } catch (e, st) {
    debugPrint('No se pudo inicializar App Check: $e\n$st');
  }
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    // Ajuste global: ThemeData y TextTheme para texto blanco/alto contraste en fondos oscuros
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.appTitle ?? 'Orbit',
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('en'),
        const Locale('es'),
      ],
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF061423),
        cardColor: const Color(0xFF122A43),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF061423),
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: Colors.white),
          displayMedium: TextStyle(color: Colors.white),
          displaySmall: TextStyle(color: Colors.white),
          headlineLarge: TextStyle(color: Colors.white),
          headlineMedium: TextStyle(color: Colors.white),
          headlineSmall: TextStyle(color: Colors.white),
          titleLarge: TextStyle(color: Colors.white),
          titleMedium: TextStyle(color: Colors.white),
          titleSmall: TextStyle(color: Colors.white),
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          bodySmall: TextStyle(color: Colors.white70),
          labelLarge: TextStyle(color: Colors.white),
          labelMedium: TextStyle(color: Colors.white),
          labelSmall: TextStyle(color: Colors.white),
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00B7FF),
          secondary: Color(0xFFFFB347),
          surface: Color(0xFF0E2238),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00B7FF),
            foregroundColor: const Color(0xFF00131F),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF00D1FF),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF10263C),
          hintStyle: const TextStyle(color: Colors.white54),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF1D3C5B)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF1D3C5B)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF00B7FF), width: 1.3),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF0A1C2F),
          selectedItemColor: Color(0xFF00D1FF),
          unselectedItemColor: Colors.white54,
          showUnselectedLabels: true,
          elevation: 8,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF11314D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      initialRoute: isLoggedIn ? '/home' : '/',
      routes: {
        '/': (_) => const WelcomeScreen(),
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/home': (_) => const HomeScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}
