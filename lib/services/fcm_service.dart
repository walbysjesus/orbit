import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:orbit/firebase/firebase_init.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseInit.init();
  await FCMService.showBackgroundDataNotificationIfNeeded(message);
  debugPrint(
      '[FCM][background] id=${message.messageId} title=${message.notification?.title}');
}

/// Servicio para inicializar y manejar notificaciones push (FCM)
/// - Solicita permisos, obtiene el token y escucha mensajes en foreground/background.
/// - Maneja errores automáticamente y expone logs para debug.
class FCMService {
  static FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _chatChannel =
      AndroidNotificationChannel(
    'orbit_messages',
    'Mensajes Orbit',
    description: 'Notificaciones de nuevos mensajes y actividad de chat',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel _callsChannel =
      AndroidNotificationChannel(
    'calls',
    'Llamadas Orbit',
    description: 'Notificaciones de llamadas entrantes',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static bool _initialized = false;
  static Future<void>? _initializationFuture;
  static bool _localNotificationsReady = false;
  static String? _activeChatPeerId;

  static const String _chatRoute = '/chat';

  static void setActiveChatPeer(String? peerUid) {
    final normalized = (peerUid ?? '').trim();
    _activeChatPeerId = normalized.isEmpty ? null : normalized;
    debugPrint('[FCM] Active chat peer: ${_activeChatPeerId ?? 'none'}');
  }

  /// Inicializa FCM, solicita permisos y configura listeners.
  static Future<void> initialize() async {
    if (_initialized) return;
    if (_initializationFuture != null) {
      return _initializationFuture;
    }

    _initializationFuture = _initializeInternal();
    try {
      await _initializationFuture;
    } finally {
      if (!_initialized) {
        _initializationFuture = null;
      }
    }
  }

  static Future<void> _initializeInternal() async {
    if (Firebase.apps.isEmpty) {
      throw StateError(
        'Firebase debe inicializarse antes de FCMService.initialize().',
      );
    }

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await _initializeLocalNotifications();
      await _requestPermissions();

      // Solicitar permisos en plataformas móviles
      // Obtener token del dispositivo
      final token = await _messaging.getToken();
      debugPrint('[FCM] token inicial: $token');

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

      // Listener: Mensajes en foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        debugPrint(
            '[FCM][foreground] id=${message.messageId} title=${message.notification?.title} data=${message.data}');
        if (_shouldSuppressForegroundNotification(message)) {
          debugPrint('[FCM][foreground] notificacion suprimida: chat activo');
          return;
        }
        await _showLocalNotificationFromMessage(message);
      });

      // Listener: Mensajes cuando la app está en background y se abre desde la notificación
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint(
            '[FCM][open] onMessageOpenedApp title=${message.notification?.title} data=${message.data}');
        _handleNotificationTapData(message.data);
      });

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint(
            '[FCM][open] getInitialMessage title=${initialMessage.notification?.title} data=${initialMessage.data}');
        _handleNotificationTapData(initialMessage.data);
      }

      _initialized = true;
    } catch (e, st) {
      debugPrint('[FCM] Error inicializando FCM: $e\n$st');
      rethrow;
    }
  }

  static Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsReady) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = Map<String, dynamic>.from(
              jsonDecode(payload) as Map<String, dynamic>);
          _handleNotificationTapData(data);
        } catch (e) {
          debugPrint('[FCM] payload local invalido: $e');
        }
      },
      onDidReceiveBackgroundNotificationResponse:
          _onDidReceiveBackgroundNotificationResponse,
    );

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_chatChannel);
    await androidPlugin?.createNotificationChannel(_callsChannel);
    _localNotificationsReady = true;
    debugPrint('[FCM] Canal Android listo: ${_chatChannel.id}');
  }

  @pragma('vm:entry-point')
  static void _onDidReceiveBackgroundNotificationResponse(
      NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = Map<String, dynamic>.from(
          jsonDecode(payload) as Map<String, dynamic>);
      _handleNotificationTapData(data);
    } catch (_) {
      // Ignorar payload inválido para no romper la apertura.
    }
  }

  static Future<void> _requestPermissions() async {
    if (kIsWeb) return;

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );
      debugPrint('[FCM] permiso FCM: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('[FCM] error solicitando permiso FCM: $e');
    }

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    try {
      final granted = await androidPlugin?.requestNotificationsPermission();
      debugPrint('[FCM] permiso Android notifications: $granted');
    } catch (e) {
      debugPrint('[FCM] error permiso Android notifications: $e');
    }
  }

  static bool _shouldSuppressForegroundNotification(RemoteMessage message) {
    final data = message.data;
    final senderId = (data['senderId'] ?? '').toString().trim();
    if (senderId.isEmpty || _activeChatPeerId == null) return false;
    return senderId == _activeChatPeerId;
  }

  static Future<void> _showLocalNotificationFromMessage(
    RemoteMessage message,
  ) async {
    if (!_localNotificationsReady) return;

    final title =
        (message.notification?.title ?? message.data['senderName'] ?? 'Orbit')
            .toString()
            .trim();
    final body = (message.notification?.body ??
            message.data['preview'] ??
            message.data['body'] ??
            'Nuevo mensaje')
        .toString()
        .trim();

    final payloadData = <String, dynamic>{
      ...message.data,
      'title': title,
      'body': body,
    };

    await _localNotifications.show(
      message.hashCode,
      title.isEmpty ? 'Orbit' : title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _chatChannel.id,
          _chatChannel.name,
          channelDescription: _chatChannel.description,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          category: AndroidNotificationCategory.message,
        ),
      ),
      payload: jsonEncode(payloadData),
    );
  }

  static Future<void> showBackgroundDataNotificationIfNeeded(
      RemoteMessage message) async {
    if (kIsWeb) return;
    // Si el backend envía notification payload, Android ya la renderiza
    // en background/terminated y evitamos duplicados.
    if (message.notification != null) return;

    await _initializeLocalNotifications();
    await _showLocalNotificationFromMessage(message);
  }

  static void _handleNotificationTapData(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString();
    final roomId = (data['roomId'] ?? '').toString();
    final senderId = (data['senderId'] ?? '').toString();
    final senderName = (data['senderName'] ?? '').toString();

    final targetPeerId = senderId.trim();
    if (targetPeerId.isEmpty) {
      debugPrint('[FCM] tap sin senderId. type=$type roomId=$roomId');
      return;
    }

    final nav = navigatorKey.currentState;
    if (nav == null) {
      debugPrint('[FCM] navigator no disponible para abrir chat');
      return;
    }

    nav.pushNamed(
      _chatRoute,
      arguments: {
        'remoteUserId': targetPeerId,
        'initialContactName': senderName,
      },
    );
  }

  static Future<void> _saveTokenToFirestore(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      // Use update() so this never triggers a Firestore "create" operation.
      // During registration the doc may not exist yet; the token is saved
      // explicitly by AuthService after the profile document is created.
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      debugPrint('[FCM] Error guardando FCM token (${e.code}): $e');
    } catch (e) {
      debugPrint('[FCM] Error guardando FCM token: $e');
    }
  }

  /// Saves the current device FCM token to Firestore.
  /// Call this after the user's Firestore profile document has been created.
  static Future<void> saveCurrentToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) await _saveTokenToFirestore(token);
    } catch (e) {
      debugPrint('[FCM] Error al guardar FCM token actual: $e');
    }
  }
}
