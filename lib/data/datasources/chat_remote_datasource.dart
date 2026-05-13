import '../../domain/entities/message_entity.dart';

abstract class ChatRemoteDataSource {
  Future<List<MessageEntity>> fetchMessages(
      {required String chatId, int limit = 20, String? startAfterId});
  Future<void> sendMessage(
      {required String chatId, required MessageEntity message});
  Stream<List<MessageEntity>> messagesStream(
      {required String chatId, int limit});
  // Implementacion concreta en chat_remote_datasource_impl.dart
}
