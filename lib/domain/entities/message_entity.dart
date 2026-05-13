class MessageEntity {
  final String id;
  final String text;
  final String? attachmentUrl;
  final String userId;
  final String userName;
  final String userAvatar;
  final DateTime createdAt;
  final String status; // sent, delivered, seen

  MessageEntity({
    required this.id,
    required this.text,
    this.attachmentUrl,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.createdAt,
    required this.status,
  });
}
