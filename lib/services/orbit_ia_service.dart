import '../ia_core/orbit_brain.dart';
import '../ia_core/orbit_context.dart';

import '../ia_memory/conversation_state.dart';

import '../ia_executor.dart/chat_executor.dart';
import '../ia_executor.dart/call_executor.dart';
import '../ia_executor.dart/status_executor.dart';
import '../ia_executor.dart/dashbord_executor.dart';

class OrbitIAService {
  static final OrbitBrain _brain = OrbitBrain();

  /// Memoria viva por conversación (runtime)
  /// Esto evita que Orbit "olvide" entre mensajes
  static final Map<String, ConversationState> _conversationStates = {};

  /// Punto ÚNICO de entrada entre UI y la IA de Orbit
  static Future<dynamic> sendMessage({
    required String userId,
    required String conversationId,
    required String message,
  }) async {
    final cleanMessage = message.trim();

    if (cleanMessage.isEmpty) {
      return _emptyMessage();
    }

    // 1️⃣ Estado de conversación persistente
    final conversationState = _conversationStates.putIfAbsent(
      conversationId,
      () => ConversationState(
        conversationId: conversationId,
        userId: userId,
      ),
    );

    // 2️⃣ Contexto cognitivo (lo que Orbit "sabe ahora")
    // TODO: Integrar servicios reales de clima y red aquí
    // Ejemplo profesional: inyección desacoplada de contexto externo
    const weatherCondition = WeatherCondition.rain; // Simulación: lluvia
    const networkQuality = "good"; // Simulación: buena red

    final context = OrbitContext(
      conversationId: conversationId,
      userId: userId,
      shortTermMemory: conversationState.shortTermMemory.snapshot(),
      longTermMemory: conversationState.longTermMemory.export(),
      lastIntent: conversationState.activeIntent,
      weatherCondition: weatherCondition,
      networkQuality: networkQuality,
    );

    // 3️⃣ La IA PIENSA (NO responde)
    final decision = _brain.process(
      message: cleanMessage,
      context: context,
    );

    // 4️⃣ Se actualiza el estado cognitivo
    conversationState.updateIntent(decision.intent.name);
    conversationState.shortTermMemory.store('last_message', cleanMessage);

    // 5️⃣ Se ejecuta lo decidido
    return _executeDecision(
      intent: decision.intent.name,
      message: cleanMessage,
      context: context,
    );
  }

  // -----------------------
  // EJECUCIÓN (PUENTE IA → SERVICIOS)
  // -----------------------

  static dynamic _executeDecision({
    required String intent,
    required String message,
    required OrbitContext context,
  }) {
    switch (intent) {
      case 'chat':
        return ChatExecutor().execute(
          message: _defaultChatResponse(message),
          context: context,
        );

      case 'action':
        CallExecutor().execute(
          callType: 'default',
          context: context,
        );
        return "Acción ejecutada correctamente.";

      case 'system':
        return StatusExecutor().execute(
          context: context,
        );

      case 'dashboard':
        return DashboardExecutor().execute(
          destination: 'default',
          context: context,
        );

      default:
        return _fallbackResponse(message);
    }
  }

  // -----------------------
  // RESPUESTAS BASE (TEMPORALES)
  // -----------------------

  static String _defaultChatResponse(String message) {
    return 'Entendido. Estoy procesando: "$message"';
  }

  static String _emptyMessage() {
    return "El mensaje llegó vacío 🤔 Escríbeme algo y lo revisamos.";
  }

  static String _fallbackResponse(String message) {
    return "No identifiqué claramente la intención, pero sigo atento 👀";
  }
}