import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:orbit/firebase/firebase_init.dart';
import 'package:orbit/screens/communication/video_call_screen.dart';

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
  static String? _activeIncomingCallSessionId;
  static final Map<String, DateTime> _recentIncomingCallNavigations =
      <String, DateTime>{};
  static const Duration _incomingCallNavigationTtl = Duration(minutes: 2);
  static bool _incomingCallNavigationInProgress = false;
  static Map<String, dynamic>? _pendingTapNavigationData;
  static bool _flushScheduled = false;

  static const String _chatRoute = '/chat';

  static void setActiveChatPeer(String? peerUid) {
    final normalized = (peerUid ?? '').trim();
    _activeChatPeerId = normalized.isEmpty ? null : normalized;
    debugPrint('[FCM] Active chat peer: ${_activeChatPeerId ?? 'none'}');
  }

  static bool isIncomingCallSessionActive(String callSessionId) {
    return _activeIncomingCallSessionId == callSessionId;
  }

  static void markIncomingCallSessionActive(String callSessionId) {
    _activeIncomingCallSessionId = callSessionId;
  }

  static void clearIncomingCallSessionActive(String callSessionId) {
    if (_activeIncomingCallSessionId == callSessionId) {
      _activeIncomingCallSessionId = null;
    }
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
      if (_pendingTapNavigationData != null) {
        _schedulePendingNavigationFlush();
      }
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
      _pendingTapNavigationData = data;
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
    final type = (message.data['type'] ?? '').toString().trim();
    final isIncomingCall = type == 'incoming_call';

    final title = (message.notification?.title ??
            message.data['senderName'] ??
            message.data['callerName'] ??
            'Orbit')
        .toString()
        .trim();
    final body = (message.notification?.body ??
            message.data['preview'] ??
            message.data['body'] ??
            (isIncomingCall ? 'Llamada entrante' : 'Nuevo mensaje'))
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
          isIncomingCall ? _callsChannel.id : _chatChannel.id,
          isIncomingCall ? _callsChannel.name : _chatChannel.name,
          channelDescription: isIncomingCall
              ? _callsChannel.description
              : _chatChannel.description,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          fullScreenIntent: isIncomingCall,
          category: isIncomingCall
              ? AndroidNotificationCategory.call
              : AndroidNotificationCategory.message,
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
    final normalizedData = Map<String, dynamic>.from(data);
    final type = (data['type'] ?? '').toString().trim();
    final roomId = (data['roomId'] ?? '').toString().trim();
    final senderId =
        (data['senderId'] ?? data['callerId'] ?? '').toString().trim();
    final senderName =
        (data['senderName'] ?? data['callerName'] ?? '').toString().trim();

    final nav = navigatorKey.currentState;
    if (nav == null) {
      _pendingTapNavigationData = normalizedData;
      _schedulePendingNavigationFlush();
      debugPrint(
          '[FCM] navigator no disponible. Se difiere navegación. type=$type');
      return;
    }

    // Manejar llamadas entrantes
    if (type == 'incoming_call') {
      _openIncomingCallScreen(normalizedData);
      return;
    }

    // Manejar mensajes de chat
    if (senderId.isEmpty) {
      debugPrint('[FCM] tap sin senderId. type=$type roomId=$roomId');
      return;
    }

    nav.pushNamed(
      _chatRoute,
      arguments: {
        'remoteUserId': senderId,
        'initialContactName': senderName,
      },
    );
  }

  static void _schedulePendingNavigationFlush() {
    if (_flushScheduled) return;
    _flushScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _flushScheduled = false;
      final pending = _pendingTapNavigationData;
      if (pending == null) return;
      final nav = navigatorKey.currentState;
      if (nav == null) {
        _schedulePendingNavigationFlush();
        return;
      }
      _pendingTapNavigationData = null;
      _handleNotificationTapData(pending);
    });
  }

  static void _openIncomingCallScreen(Map<String, dynamic> data) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    final callSessionId =
        (data['callSessionId'] ?? data['callId'] ?? '').toString().trim();
    final callerId =
        (data['callerId'] ?? data['senderId'] ?? '').toString().trim();
    if (callSessionId.isEmpty || callerId.isEmpty) {
      debugPrint(
          '[FCM] incoming_call incompleto: callSessionId=$callSessionId callerId=$callerId');
      return;
    }

    _pruneRecentIncomingCallNavigations();
    if (_recentIncomingCallNavigations.containsKey(callSessionId)) {
      debugPrint('[FCM] incoming_call duplicado ignorado: $callSessionId');
      return;
    }
    if (_incomingCallNavigationInProgress) {
      debugPrint('[FCM] incoming_call ignorado: navegación en curso');
      return;
    }

    if (isIncomingCallSessionActive(callSessionId)) {
      return;
    }

    final callerName =
        (data['callerName'] ?? data['senderName'] ?? '').toString().trim();
    final callType = (data['callType'] ?? '').toString().trim().toLowerCase();
    final isVideoFlag =
        (data['isVideo'] ?? 'false').toString().toLowerCase() == 'true';
    final audioOnly = !(callType == 'video' || isVideoFlag);

    markIncomingCallSessionActive(callSessionId);
    _incomingCallNavigationInProgress = true;
    _recentIncomingCallNavigations[callSessionId] = DateTime.now();
    nav
        .push(
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          remoteUserId: callerId,
          initialRemoteDisplayName: callerName.isEmpty ? 'Usuario' : callerName,
          callSessionId: callSessionId,
          isCaller: false,
          audioOnly: audioOnly,
        ),
      ),
    )
        .whenComplete(() {
      _incomingCallNavigationInProgress = false;
      clearIncomingCallSessionActive(callSessionId);
    });
  }

  static void _pruneRecentIncomingCallNavigations() {
    final now = DateTime.now();
    _recentIncomingCallNavigations.removeWhere(
      (_, timestamp) => now.difference(timestamp) > _incomingCallNavigationTtl,
    );
  }

  static void openIncomingCallFromData(Map<String, dynamic> data) {
    _openIncomingCallScreen(Map<String, dynamic>.from(data));
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
