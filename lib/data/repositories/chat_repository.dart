import '../../domain/entities/message_entity.dart';

abstract class ChatRepository {
  Future<List<MessageEntity>> fetchMessages(
      {required String chatId, int limit = 20, String? startAfterId});
  Future<void> sendMessage(
      {required String chatId, required MessageEntity message});
  Stream<List<MessageEntity>> messagesStream(
      {required String chatId, int limit});
  // TODO: Add more methods for reactions, edit, delete, etc.
}
