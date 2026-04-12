import 'weather_service.dart';
import 'network_service.dart';
import '../ia_core/orbit_brain.dart';
import '../ia_core/orbit_context.dart';
import '../ia_core/decision_engine.dart';

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

  /// Punto ÚNICO de entrada entre UI y la IA de Orbit.
  /// Siempre retorna texto para evitar errores en UI.
  static Future<String> sendMessage({
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

    // Obtener clima real (ejemplo: lat/lon fijos, reemplazar por GPS real si se desea)
    final weatherCondition = await WeatherService.getCurrentWeather(
        lat: 19.4326, lon: -99.1332); // CDMX
    final networkService = NetworkService();
    final networkQuality = await networkService.getNetworkQuality();
    final latencyMs = await networkService.measureLatencyMs();

    final context = OrbitContext(
      conversationId: conversationId,
      userId: userId,
      shortTermMemory: conversationState.shortTermMemory.snapshot(),
      longTermMemory: conversationState.longTermMemory.export(),
      lastIntent: conversationState.activeIntent,
      weatherCondition: weatherCondition,
      networkQuality: networkQuality.name,
    );
    context.rememberShortTerm('latencyMs', latencyMs);
    context.rememberShortTerm(
      'recommendedMode',
      _recommendedMode(networkQuality.name, latencyMs),
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

  static Future<String> _executeDecision({
    required String intent,
    required String message,
    required OrbitContext context,
  }) async {
    switch (intent) {
      case 'chat':
        return ChatExecutor().execute(
          message: _defaultChatResponse(message, context),
          context: context,
        );

      case 'action':
        await CallExecutor().execute(
          callType: 'default',
          context: context,
        );
        return 'Accion ejecutada correctamente.\n${_networkAdvice(context)}';

      case 'system':
        final status = StatusExecutor().execute(
          context: context,
        );
        return _formatStatus(status, context);

      case 'dashboard':
        DashboardExecutor().execute(
          destination: 'default',
          context: context,
        );
        return 'Navegación de dashboard preparada.';

      default:
        return _fallbackResponse(message);
    }
  }

  static String _formatStatus(
      Map<String, dynamic> status, OrbitContext context) {
    final intent = status['lastIntent'] ?? 'unknown';
    final shortMem = status['shortTermMemorySize'] ?? 0;
    final longMem = status['longTermMemorySize'] ?? 0;

    return 'Estado Orbit: intent=$intent, memoriaCorta=$shortMem, memoriaLarga=$longMem.\n${_networkAdvice(context)}';
  }

  // -----------------------
  // RESPUESTAS BASE (TEMPORALES)
  // -----------------------

  static String _defaultChatResponse(String message, OrbitContext context) {
    return 'Entendido. Estoy procesando: "$message"\n${_networkAdvice(context)}';
  }

  static String _emptyMessage() {
    return "El mensaje llegó vacío 🤔 Escríbeme algo y lo revisamos.";
  }

  static String _fallbackResponse(String message) {
    return "No identifiqué claramente la intención, pero sigo atento 👀";
  }

  static String _recommendedMode(String quality, int? latencyMs) {
    if (quality == 'none') {
      return 'chat';
    }
    if (quality == 'low') {
      return 'chat';
    }
    if (quality == 'medium') {
      if (latencyMs != null && latencyMs > 240) {
        return 'chat';
      }
      return 'voz o chat';
    }
    if (quality == 'high') {
      if (latencyMs != null && latencyMs > 200) {
        return 'llamada de voz';
      }
      return 'todos los servicios';
    }
    return 'chat';
  }

  static String _networkAdvice(OrbitContext context) {
    final quality = context.networkQuality;
    final weather = context.weatherCondition;
    final latency = context.recall('latencyMs') as int?;
    final mode = context.recall('recommendedMode')?.toString() ?? 'chat';

    final qualityLabel = switch (quality) {
      'high' => 'alta',
      'medium' => 'media',
      'low' => 'baja',
      'none' => 'sin conexion',
      _ => 'desconocida',
    };

    final weatherAdvice = switch (weather) {
      WeatherCondition.storm =>
        'Clima: tormenta detectada, prioriza audio o chat por estabilidad.',
      WeatherCondition.rain =>
        'Clima: lluvia activa, evita videollamadas prolongadas si hay variaciones.',
      WeatherCondition.fog =>
        'Clima: niebla, se recomienda comunicación por voz o chat.',
      WeatherCondition.extremeHeat =>
        'Clima: calor extremo, limita sesiones largas de video.',
      WeatherCondition.clear => 'Clima: condiciones estables para comunicarte.',
      WeatherCondition.unknown =>
        'Clima: sin datos confiables en este momento.',
    };

    final latencyLabel = latency == null ? 'no disponible' : '$latency ms';
    final modeAdvice = mode == 'todos los servicios'
        ? 'Recomendacion: señal óptima para chat, voz y videollamada.'
        : 'Recomendacion: usar $mode.';
    return 'Estado de señal: $qualityLabel. Latencia estimada: $latencyLabel. $modeAdvice $weatherAdvice';
  }
}
