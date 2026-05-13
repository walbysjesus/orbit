import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/message_entity.dart';
import 'chat_remote_datasource.dart';

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  @override
  Stream<List<MessageEntity>> messagesStream(
      {required String chatId, int limit = 20}) {
    return firestore
        .collection('messages')
        .where('roomId', isEqualTo: chatId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              final createdAt = (data['timestamp'] as Timestamp?) ??
                  (data['createdAt'] as Timestamp?);
              return MessageEntity(
                id: doc.id,
                text: data['text'] ?? '',
                attachmentUrl: data['fileUrl'] ?? data['audioUrl'],
                userId: data['senderId'] ?? '',
                userName: data['senderName'] ?? '',
                userAvatar: data['senderAvatar'] ?? '',
                createdAt: createdAt?.toDate() ?? DateTime.now(),
                status: data['status'] ?? 'sent',
              );
            }).toList());
  }

  final FirebaseFirestore firestore;
  ChatRemoteDataSourceImpl(this.firestore);

  @override
  Future<List<MessageEntity>> fetchMessages({
    required String chatId,
    int limit = 20,
    String? startAfterId,
  }) async {
    Query query = firestore
        .collection('messages')
        .where('roomId', isEqualTo: chatId)
        .orderBy('timestamp', descending: true)
        .limit(limit);
    if (startAfterId != null) {
      final startAfterDoc =
          await firestore.collection('messages').doc(startAfterId).get();
      if (startAfterDoc.exists) {
        query = query.startAfterDocument(startAfterDoc);
      }
    }
    final snap = await query.get();
    return snap.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final createdAt = (data['timestamp'] as Timestamp?) ??
          (data['createdAt'] as Timestamp?);
      return MessageEntity(
        id: doc.id,
        text: data['text'] ?? '',
        attachmentUrl: data['fileUrl'] ?? data['audioUrl'],
        userId: data['senderId'] ?? '',
        userName: data['senderName'] ?? '',
        userAvatar: data['senderAvatar'] ?? '',
        createdAt: createdAt?.toDate() ?? DateTime.now(),
        status: data['status'] ?? 'sent',
      );
    }).toList();
  }

  @override
  Future<void> sendMessage({
    required String chatId,
    required MessageEntity message,
  }) async {
    await firestore.collection('messages').add({
      'roomId': chatId,
      'text': message.text,
      'fileUrl': message.attachmentUrl ?? '',
      'audioUrl': '',
      'senderId': message.userId,
      'senderName': message.userName,
      'senderAvatar': message.userAvatar,
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'text',
      'metadata': <String, dynamic>{},
      'status': message.status,
    });
  }
}
