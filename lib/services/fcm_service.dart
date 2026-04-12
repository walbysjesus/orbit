import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM Background: ${message.notification?.title}');
}

/// Servicio para inicializar y manejar notificaciones push (FCM)
/// - Solicita permisos, obtiene el token y escucha mensajes en foreground/background.
/// - Maneja errores automáticamente y expone logs para debug.
class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Inicializa FCM, solicita permisos y configura listeners.
  static Future<void> initialize() async {
    try {
      // Solicitar permisos en plataformas móviles
      if (!kIsWeb) {
        await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      // Obtener token del dispositivo
      final token = await _messaging.getToken();
      debugPrint('FCM Token: $token');

      if (token != null) {
        await _saveTokenToFirestore(token);
      }

      // Guardar token cuando se renueva
      _messaging.onTokenRefresh.listen(_saveTokenToFirestore);

      // Guardar token cuando el usuario inicia sesión (en caso de que
      // initialize() se haya llamado antes del login)
      FirebaseAuth.instance.authStateChanges().listen((user) async {
        if (user != null) {
          final currentToken = await _messaging.getToken();
          if (currentToken != null) {
            await _saveTokenToFirestore(currentToken);
          }
        }
      });

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Listener: Mensajes en foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint(
            'FCM Foreground: ${message.notification?.title} - ${message.notification?.body}');
      });

      // Listener: Mensajes cuando la app está en background y se abre desde la notificación
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM onMessageOpenedApp: ${message.notification?.title}');
      });
    } catch (e, st) {
      debugPrint('Error inicializando FCM: $e\n$st');
    }
  }

  static Future<void> _saveTokenToFirestore(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error guardando FCM token: $e');
    }
  }
}
