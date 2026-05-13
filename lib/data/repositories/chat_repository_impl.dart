import '../../domain/entities/message_entity.dart';
import '../datasources/chat_remote_datasource.dart';
import 'chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  @override
  Stream<List<MessageEntity>> messagesStream(
      {required String chatId, int limit = 20}) {
    return remoteDataSource.messagesStream(chatId: chatId, limit: limit);
  }

  final ChatRemoteDataSource remoteDataSource;
  ChatRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<MessageEntity>> fetchMessages(
      {required String chatId, int limit = 20, String? startAfterId}) {
    return remoteDataSource.fetchMessages(
        chatId: chatId, limit: limit, startAfterId: startAfterId);
  }

  @override
  Future<void> sendMessage(
      {required String chatId, required MessageEntity message}) {
    return remoteDataSource.sendMessage(chatId: chatId, message: message);
  }
}
