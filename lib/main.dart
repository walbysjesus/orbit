import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/config/config.dart';
import 'package:orbit/firebase_options.dart';
import 'package:orbit/services/subscription_service.dart';
import 'package:orbit/services/locale_service.dart';

import 'screens/auth/welcome_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/communication/chat_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/settings_screen.dart';

import 'services/auth_service.dart';
import 'services/fcm_service.dart';
import 'services/remote_config_service.dart';

/// Punto de entrada principal de la app Orbit.
/// Inicializa Firebase y FCM (notificaciones push) con control de errores automático.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kReleaseMode) {
    debugPrint = (String? _, {int? wrapWidth}) {};
    FlutterError.onError = (FlutterErrorDetails details) {
      Zone.current.handleUncaughtError(
        details.exception,
        details.stack ?? StackTrace.empty,
      );
    };
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      return true;
    };
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  String? startupError;
  var loggedIn = false;
  final supportsConfiguredFirebase = _supportsConfiguredFirebase();

  try {
    if (supportsConfiguredFirebase) {
      validateProductionSecurityConfig();
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      await configureFirebaseServices();
      await _initializeAppCheck();
      loggedIn = await AuthService.isLoggedIn();
    } else {
      debugPrint(
        'Firebase no configurado para esta plataforma. Inicio en modo local.',
      );
    }
  } catch (e, st) {
    startupError = 'Error de inicio controlado: $e';
    debugPrint('$startupError\n$st');
  }

  runApp(MyApp(isLoggedIn: loggedIn, startupError: startupError));

  // Servicios no críticos: se inicializan después del primer frame
  // para no bloquear la aparición de la UI.
  if (startupError != null) {
    return;
  }

  if (!supportsConfiguredFirebase) {
    return;
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
    FCMService.initialize().catchError(
      (e) => debugPrint('FCM init error: $e'),
    );
    RemoteConfigService().initialize().catchError(
          (e) => debugPrint('RemoteConfig init error: $e'),
        );
    subscriptionService
        .upgradeTo(SubscriptionLevel.free)
        .catchError((e) => debugPrint('Subscription init error: $e'));
  });
}

bool _supportsConfiguredFirebase() {
  if (kIsWeb) {
    return false;
  }

  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
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
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
      );
      debugPrint('App Check debug activado');
    } catch (e, st) {
      debugPrint('No se pudo activar App Check debug: $e\n$st');
    }
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

class MyApp extends StatefulWidget {
  final bool isLoggedIn;
  final String? startupError;

  const MyApp({
    super.key,
    required this.isLoggedIn,
    this.startupError,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Locale _locale;

  @override
  void initState() {
    super.initState();
    _locale = localeNotifier.value;
    localeNotifier.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    localeNotifier.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() => _locale = localeNotifier.value);
  }

  @override
  Widget build(BuildContext context) {
    // Tema global: fondo blanco y acciones azules para una UI limpia y consistente.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: FCMService.navigatorKey,
      locale: _locale,
      home: widget.startupError == null
          ? null
          : StartupFailureScreen(details: widget.startupError!),
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.appTitle ?? 'Orbit',
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        cardColor: const Color(0xFFFFFFFF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFFFF),
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF0A4D8F)),
          titleTextStyle: TextStyle(
            color: Color(0xFF0A4D8F),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: Color(0xFF123A5B)),
          displayMedium: TextStyle(color: Color(0xFF123A5B)),
          displaySmall: TextStyle(color: Color(0xFF123A5B)),
          headlineLarge: TextStyle(color: Color(0xFF123A5B)),
          headlineMedium: TextStyle(color: Color(0xFF123A5B)),
          headlineSmall: TextStyle(color: Color(0xFF123A5B)),
          titleLarge: TextStyle(color: Color(0xFF123A5B)),
          titleMedium: TextStyle(color: Color(0xFF123A5B)),
          titleSmall: TextStyle(color: Color(0xFF123A5B)),
          bodyLarge: TextStyle(color: Color(0xFF123A5B)),
          bodyMedium: TextStyle(color: Color(0xFF123A5B)),
          bodySmall: TextStyle(color: Color(0xFF5A7388)),
          labelLarge: TextStyle(color: Color(0xFF123A5B)),
          labelMedium: TextStyle(color: Color(0xFF123A5B)),
          labelSmall: TextStyle(color: Color(0xFF123A5B)),
        ),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0A4D8F),
          secondary: Color(0xFF2F94FF),
          surface: Color(0xFFFFFFFF),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0A4D8F),
            foregroundColor: const Color(0xFFFFFFFF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF0A4D8F),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFFFFFF),
          hintStyle: const TextStyle(color: Color(0xFF7A8FA4)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFBCD8EE)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFBCD8EE)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF0A4D8F), width: 1.3),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFFFFFFFF),
          selectedItemColor: Color(0xFF0A4D8F),
          unselectedItemColor: Color(0xFF4B78A1),
          showUnselectedLabels: true,
          elevation: 8,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF0A4D8F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      initialRoute: widget.startupError == null
          ? (widget.isLoggedIn ? '/home' : '/')
          : null,
      routes: {
        '/': (_) => const WelcomeScreen(),
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/home': (_) => const HomeScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name != '/chat') return null;
        final args = settings.arguments as Map<String, dynamic>?;
        final remoteUserId = (args?['remoteUserId'] ?? '').toString().trim();
        if (remoteUserId.isEmpty) return null;

        final initialContactName =
            (args?['initialContactName'] as String?)?.trim();

        return MaterialPageRoute(
          builder: (_) => ChatScreen(
            remoteUserId: remoteUserId,
            initialContactName:
                (initialContactName == null || initialContactName.isEmpty)
                    ? null
                    : initialContactName,
          ),
        );
      },
      builder: (context, child) => child ?? const SizedBox.shrink(),
    );
  }
}

class StartupFailureScreen extends StatelessWidget {
  final String details;

  const StartupFailureScreen({
    super.key,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 52,
                      color: Color(0xFF8A1F11),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No se pudo iniciar Firebase',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF123A5B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'La app quedó en modo seguro para evitar un cierre inesperado. Revisa la configuración de Firebase e inténtalo de nuevo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF4B6178),
                        height: 1.4,
                      ),
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9ECEA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          details,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8A1F11),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
