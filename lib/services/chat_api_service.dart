import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';
import 'organization_service.dart';
import 'remote_notification_service.dart';
import 'resilient_stream_helper.dart';

/// Servicio de chat real-time usando Firestore.
/// Los mensajes se guardan en:
///   /chats/{roomId}/messages/{messageId}
/// donde roomId es el ID de sala compartido entre los dos usuarios.
class ChatApiService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ──────────────────────────────────────────────
  // ROOMS
  // ──────────────────────────────────────────────

  /// Devuelve (o crea) la sala 1:1 entre el usuario actual y [otherUserId].
  /// El roomId es determinístico: uid menor + _ + uid mayor para evitar duplicados.
  static Future<String> getOrCreateRoom(String otherUserId) async {
    final me = _auth.currentUser;
    if (me == null) throw StateError('No hay sesión activa');
    if (me.uid == otherUserId) {
      throw ArgumentError('No puedes chatear contigo mismo');
    }
    await AuthService.ensureCommunicationAccess();

    final ids = [me.uid, otherUserId]..sort();
    final roomId = '${ids[0]}_${ids[1]}';

    final ref = _db.collection('chats').doc(roomId);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'participants': [me.uid, otherUserId],
        'createdBy': me.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    return roomId;
  }

  // ──────────────────────────────────────────────
  // MESSAGES
  // ──────────────────────────────────────────────

  /// Stream en tiempo real de mensajes de una sala, ordenados por timestamp.
  static Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream(
    String roomId, {
    void Function(ResilientStreamStatus status)? onStatus,
  }) {
    return ResilientStreamHelper.resilientStream(
      streamFactory: () => _db
          .collection('chats')
          .doc(roomId)
          .collection('messages')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      timeout: const Duration(seconds: 15),
      onStatus: onStatus,
      logTag: 'ChatApiMessagesStream:$roomId',
    );
  }

  /// Envía un mensaje de texto a la sala [roomId].
  static Future<void> sendTextMessage({
    required String roomId,
    required String text,
  }) async {
    final me = _auth.currentUser;
    if (me == null) throw StateError('No hay sesión activa');
    if (text.trim().isEmpty) return;
    await AuthService.ensureCommunicationAccess();

    final batch = _db.batch();

    final msgRef =
        _db.collection('chats').doc(roomId).collection('messages').doc();

    batch.set(msgRef, {
      'userId': me.uid,
      'text': text.trim(),
      'attachment': null,
      'attachmentName': null,
      'favorite': false,
      'reaction': null,
      'replyTo': null,
      'replyToText': null,
      'status': 'sent',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Actualizar updatedAt de la sala
    batch.update(_db.collection('chats').doc(roomId), {
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    final roomSnap = await _db.collection('chats').doc(roomId).get();
    final participants =
        (roomSnap.data()?['participants'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList();
    final otherUserId = participants.firstWhere(
      (uid) => uid != me.uid,
      orElse: () => '',
    );
    if (otherUserId.isNotEmpty) {
      final preview = text.trim().length > 80
          ? '${text.trim().substring(0, 80)}...'
          : text.trim();
      await RemoteNotificationService.notifyUser(
        targetUserId: otherUserId,
        type: 'chat_message',
        title: 'Nuevo mensaje',
        body: preview,
        data: {
          'roomId': roomId,
          'senderId': me.uid,
        },
      );
    }

    await OrganizationService.recordUsageForUser(
      uid: me.uid,
      messagesIncrement: 1,
    );
  }

  /// Envía un mensaje con URL de archivo (imagen, audio, etc.) a la sala.
  static Future<void> sendMediaMessage({
    required String roomId,
    required String fileUrl,
    required String type, // 'image' | 'audio' | 'file'
    String? fileName,
    Map<String, dynamic>? metadata,
  }) async {
    final me = _auth.currentUser;
    if (me == null) throw StateError('No hay sesión activa');
    await AuthService.ensureCommunicationAccess();

    await _db.collection('chats').doc(roomId).collection('messages').add({
      'userId': me.uid,
      'text': '',
      'attachment': fileUrl,
      'attachmentName': fileName,
      'favorite': false,
      'reaction': null,
      'replyTo': null,
      'replyToText': null,
      'status': 'sent',
      'type': type,
      'metadata': {
        ...?metadata,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('chats').doc(roomId).update({
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final roomSnap = await _db.collection('chats').doc(roomId).get();
    final participants =
        (roomSnap.data()?['participants'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList();
    final otherUserId = participants.firstWhere(
      (uid) => uid != me.uid,
      orElse: () => '',
    );
    if (otherUserId.isNotEmpty) {
      final mediaLabel = switch (type) {
        'image' => 'Te enviaron una imagen',
        'video' => 'Te enviaron un video',
        'audio' => 'Te enviaron una nota de voz',
        _ => 'Te enviaron un archivo',
      };
      await RemoteNotificationService.notifyUser(
        targetUserId: otherUserId,
        type: 'chat_media',
        title: 'Nuevo mensaje',
        body: mediaLabel,
        data: {
          'roomId': roomId,
          'senderId': me.uid,
          'mediaType': type,
        },
      );
    }

    await OrganizationService.recordUsageForUser(
      uid: me.uid,
      messagesIncrement: 1,
    );
  }
}
