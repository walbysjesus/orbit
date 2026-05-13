import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../data/datasources/chat_remote_datasource_impl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/message_entity.dart';

import 'dart:io';
import '../../services/storage_service.dart';
import '../../services/remote_notification_service.dart';

final chatMessagesStreamProvider =
    StreamProvider.family<List<MessageEntity>, String>((ref, chatId) {
  final repo =
      ChatRepositoryImpl(ChatRemoteDataSourceImpl(FirebaseFirestore.instance));
  return repo.messagesStream(chatId: chatId, limit: 50);
});

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>(
  (ref) {
    final repo = ChatRepositoryImpl(
        ChatRemoteDataSourceImpl(FirebaseFirestore.instance));
    return ChatNotifier(repo);
  },
);

class ChatState {
  final List<MessageEntity> messages;
  final bool loading;
  final String? error;
  final bool hasMore;
  final String? lastMessageId;

  ChatState({
    this.messages = const [],
    this.loading = false,
    this.error,
    this.hasMore = true,
    this.lastMessageId,
  });

  ChatState copyWith({
    List<MessageEntity>? messages,
    bool? loading,
    String? error,
    bool? hasMore,
    String? lastMessageId,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        loading: loading ?? this.loading,
        error: error,
        hasMore: hasMore ?? this.hasMore,
        lastMessageId: lastMessageId ?? this.lastMessageId,
      );
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatRepository repo;
  static const int pageSize = 20;
  ChatNotifier(this.repo) : super(ChatState());

  /// Carga los primeros mensajes (paginación descendente)
  Future<void> loadMessages(String chatId) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final messages =
          await repo.fetchMessages(chatId: chatId, limit: pageSize);
      final hasMore = messages.length == pageSize;
      final lastId = messages.isNotEmpty ? messages.last.id : null;
      state = state.copyWith(
        messages: messages,
        loading: false,
        hasMore: hasMore,
        lastMessageId: lastId,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// Carga más mensajes para paginación infinita
  Future<void> loadMoreMessages(String chatId) async {
    if (!state.hasMore || state.loading) return;
    state = state.copyWith(loading: true);
    try {
      final more = await repo.fetchMessages(
        chatId: chatId,
        limit: pageSize,
        startAfterId: state.lastMessageId,
      );
      final hasMore = more.length == pageSize;
      final lastId = more.isNotEmpty ? more.last.id : state.lastMessageId;
      state = state.copyWith(
        messages: [...state.messages, ...more],
        loading: false,
        hasMore: hasMore,
        lastMessageId: lastId,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> sendMessage(String chatId, MessageEntity message) async {
    try {
      // Encoding seguro del texto
      final safeText = message.text.trim();
      final msg = MessageEntity(
        id: message.id,
        text: safeText,
        attachmentUrl: message.attachmentUrl,
        userId: message.userId,
        userName: message.userName,
        userAvatar: message.userAvatar,
        createdAt: message.createdAt,
        status: 'sent',
      );
      await repo.sendMessage(chatId: chatId, message: msg);
      await loadMessages(chatId);
      // Notificación push al destinatario (si no es el mismo usuario)
      if (msg.userId != chatId) {
        await RemoteNotificationService.notifyUser(
          targetUserId: chatId,
          type: 'chat',
          title: msg.userName,
          body: msg.text.isNotEmpty ? msg.text : '[Archivo adjunto]',
        );
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Envía un mensaje con adjunto (archivo local) y sube el archivo a Firebase Storage.
  Future<void> sendMessageWithAttachment({
    required String chatId,
    required MessageEntity message,
    required File file,
    required String fileName,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final storagePath =
          'chat_attachments/$chatId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final url =
          await StorageService.uploadFile(file: file, path: storagePath);
      final safeText = message.text.trim();
      final messageWithAttachment = MessageEntity(
        id: message.id,
        text: safeText,
        attachmentUrl: url,
        userId: message.userId,
        userName: message.userName,
        userAvatar: message.userAvatar,
        createdAt: message.createdAt,
        status: 'sent',
      );
      await repo.sendMessage(chatId: chatId, message: messageWithAttachment);
      await loadMessages(chatId);
      // Notificación push al destinatario (si no es el mismo usuario)
      if (messageWithAttachment.userId != chatId) {
        await RemoteNotificationService.notifyUser(
          targetUserId: chatId,
          type: 'chat',
          title: messageWithAttachment.userName,
          body: messageWithAttachment.text.isNotEmpty
              ? messageWithAttachment.text
              : '[Archivo adjunto]',
        );
      }
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    } finally {
      state = state.copyWith(loading: false);
    }
  }
}
