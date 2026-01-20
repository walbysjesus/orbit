import '../ia_core/orbit_context.dart';

class ChatIntent {
  final String message;

  ChatIntent(this.message);

  void applyContext(OrbitContext context) {
    context.rememberShortTerm('chat_last_message', message);
  }

  bool shouldRespond() {
    return message.trim().isNotEmpty;
  }
}
