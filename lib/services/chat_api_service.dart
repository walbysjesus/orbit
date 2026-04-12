import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Servicio de chat real-time usando Firestore.
/// Los mensajes se guardan en:
///   /chatRooms/{roomId}/messages/{messageId}
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

    final ids = [me.uid, otherUserId]..sort();
    final roomId = '${ids[0]}_${ids[1]}';

    final ref = _db.collection('chatRooms').doc(roomId);
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
      String roomId) {
    return _db
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  /// Envía un mensaje de texto a la sala [roomId].
  static Future<void> sendTextMessage({
    required String roomId,
    required String text,
  }) async {
    final me = _auth.currentUser;
    if (me == null) throw StateError('No hay sesión activa');
    if (text.trim().isEmpty) return;

    final batch = _db.batch();

    final msgRef =
        _db.collection('chatRooms').doc(roomId).collection('messages').doc();

    batch.set(msgRef, {
      'senderId': me.uid,
      'text': text.trim(),
      'type': 'text',
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Actualizar updatedAt de la sala
    batch.update(_db.collection('chatRooms').doc(roomId), {
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
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

    await _db.collection('chatRooms').doc(roomId).collection('messages').add({
      'senderId': me.uid,
      'type': type,
      'fileUrl': fileUrl,
      'metadata': {
        'fileName': fileName,
        ...?metadata,
      },
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _db.collection('chatRooms').doc(roomId).update({
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
