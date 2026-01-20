import '../ia_core/orbit_context.dart';

class ChatExecutor {
  String execute({
    required String message,
    required OrbitContext context,
  }) {
    context.rememberShortTerm('last_chat_response', message);

    // Aquí solo se devuelve texto ya decidido por la IA
    return message;
  }
}