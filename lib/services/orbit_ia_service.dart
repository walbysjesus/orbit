import 'dart:convert';

import 'weather_service.dart';
import 'network_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ia_core/orbit_brain.dart';
import '../ia_core/orbit_context.dart';
import '../ia_core/decision_engine.dart';

import '../ia_memory/conversation_state.dart';

import '../ia_executor.dart/chat_executor.dart';
import '../ia_executor.dart/call_executor.dart';
import '../ia_executor.dart/status_executor.dart';
import '../ia_executor.dart/dashbord_executor.dart';
import 'orbit_llm_service.dart';

class OrbitIAResponse {
  final String text;
  final String source;
  final String intent;
  final int latencyMs;
  final Map<String, dynamic> metadata;

  OrbitIAResponse({
    required this.text,
    required this.source,
    required this.intent,
    required this.latencyMs,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? const {};
}

class OrbitIAService {
  static final OrbitBrain _brain = OrbitBrain();
  static const String _memoryPrefix = 'orbit_ia_memory_v1_';

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
    final detailed = await sendMessageDetailed(
      userId: userId,
      conversationId: conversationId,
      message: message,
    );
    return detailed.text;
  }

  static Future<OrbitIAResponse> sendMessageDetailed({
    required String userId,
    required String conversationId,
    required String message,
  }) async {
    final total = Stopwatch()..start();
    final cleanMessage = message.trim();

    if (cleanMessage.isEmpty) {
      total.stop();
      return OrbitIAResponse(
        text: _emptyMessage(),
        source: 'empty_input',
        intent: 'unknown',
        latencyMs: total.elapsedMilliseconds,
      );
    }

    try {
      // 1) Estado de conversación persistente
      final conversationState = _conversationStates.putIfAbsent(
        conversationId,
        () => ConversationState(
          conversationId: conversationId,
          userId: userId,
        ),
      );
      await _hydrateConversationState(conversationState);

      // 2) Contexto cognitivo tolerante a fallos
      final weatherCondition = await _safeWeather();
      final networkQualityName = await _safeNetworkQualityName();
      final latencyMs = await _safeLatencyMs();

      final context = OrbitContext(
        conversationId: conversationId,
        userId: userId,
        shortTermMemory: conversationState.shortTermMemory.snapshot(),
        longTermMemory: conversationState.longTermMemory.export(),
        lastIntent: conversationState.activeIntent,
        weatherCondition: weatherCondition,
        networkQuality: networkQualityName,
      );
      context.rememberShortTerm('latencyMs', latencyMs);
      context.rememberShortTerm(
        'recommendedMode',
        _recommendedMode(networkQualityName, latencyMs),
      );
      _learnFromMessage(context, cleanMessage);

      // 3) La IA piensa
      final decision = _brain.process(
        message: cleanMessage,
        context: context,
      );

      // 4) Se actualiza estado cognitivo
      conversationState.updateIntent(decision.intent.name);
      conversationState.shortTermMemory.store('last_message', cleanMessage);

      // 5) Se ejecuta lo decidido
      final response = await _executeDecision(
        intent: decision.intent.name,
        message: cleanMessage,
        context: context,
      );
      _syncContextToState(context, conversationState);
      await _persistConversationState(conversationState);
      total.stop();
      return OrbitIAResponse(
        text: response.text,
        source: response.source,
        intent: decision.intent.name,
        latencyMs: total.elapsedMilliseconds,
        metadata: {
          ...response.metadata,
          'networkQuality': context.networkQuality,
          'weather': context.weatherCondition.name,
        },
      );
    } catch (_) {
      // Garantiza respuesta para que la UI no falle aunque haya errores internos.
      total.stop();
      return OrbitIAResponse(
        text:
            'Estoy teniendo una intermitencia técnica, pero sigo activo. Intenta de nuevo en unos segundos.',
        source: 'error_fallback',
        intent: 'unknown',
        latencyMs: total.elapsedMilliseconds,
      );
    }
  }

  static Future<void> _hydrateConversationState(ConversationState state) async {
    if (state.shortTermMemory.recall('hydrated') == true) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_memoryPrefix${state.conversationId}');
      if (raw == null || raw.isEmpty) {
        state.shortTermMemory.store('hydrated', true);
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        state.shortTermMemory.store('hydrated', true);
        return;
      }

      final shortTerm = decoded['shortTerm'];
      if (shortTerm is Map<String, dynamic>) {
        shortTerm.forEach((key, value) {
          state.shortTermMemory.store(key, value);
        });
      }

      final longTerm = decoded['longTerm'];
      if (longTerm is Map<String, dynamic>) {
        longTerm.forEach((key, value) {
          state.longTermMemory.store(key, value);
        });
      }

      final savedIntent = decoded['activeIntent'];
      if (savedIntent is String && savedIntent.isNotEmpty) {
        state.activeIntent = savedIntent;
      }
    } catch (_) {
      // Si la memoria local falla, la IA sigue operando sin bloquear la respuesta.
    } finally {
      state.shortTermMemory.store('hydrated', true);
    }
  }

  static Future<void> _persistConversationState(ConversationState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_memoryPrefix${state.conversationId}',
        jsonEncode(state.snapshot()),
      );
    } catch (_) {
      // Persistencia best-effort.
    }
  }

  static void _syncContextToState(
    OrbitContext context,
    ConversationState state,
  ) {
    context.shortTermMemory.forEach((key, value) {
      state.shortTermMemory.store(key, value);
    });
    context.longTermMemory.forEach((key, value) {
      state.longTermMemory.store(key, value);
    });
  }

  static void _learnFromMessage(OrbitContext context, String message) {
    final text = message.toLowerCase();

    if (text.contains('transport') ||
        text.contains('logistica') ||
        text.contains('flota') ||
        text.contains('entrega')) {
      context.rememberLongTerm('business_sector', 'transportadora');
    }

    if (text.contains('costo') || text.contains('combustible')) {
      context.rememberLongTerm('priority', 'costos');
    } else if (text.contains('puntual') || text.contains('tiempo')) {
      context.rememberLongTerm('priority', 'puntualidad');
    } else if (text.contains('seguridad') || text.contains('riesgo')) {
      context.rememberLongTerm('priority', 'seguridad');
    }
  }

  static Future<WeatherCondition> _safeWeather() async {
    try {
      return await WeatherService.getCurrentWeather(lat: 19.4326, lon: -99.1332)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      return WeatherCondition.unknown;
    }
  }

  static Future<String> _safeNetworkQualityName() async {
    try {
      final quality = await NetworkService()
          .getNetworkQuality()
          .timeout(const Duration(seconds: 2));
      return quality.name;
    } catch (_) {
      return 'unknown';
    }
  }

  static Future<int?> _safeLatencyMs() async {
    try {
      return await NetworkService()
          .measureLatencyMs()
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      return null;
    }
  }

  // -----------------------
  // EJECUCIÓN (PUENTE IA → SERVICIOS)
  // -----------------------

  static Future<OrbitIAResponse> _executeDecision({
    required String intent,
    required String message,
    required OrbitContext context,
  }) async {
    switch (intent) {
      case 'chat':
        final remoteResponse =
            await OrbitLlmService.tryGenerateResponseDetailed(
          message: message,
          context: context,
        );
        if (remoteResponse != null && remoteResponse.text.isNotEmpty) {
          return OrbitIAResponse(
            text: ChatExecutor().execute(
              message: remoteResponse.text,
              context: context,
            ),
            source: 'remote_llm',
            intent: intent,
            latencyMs: remoteResponse.latencyMs,
            metadata: {
              'provider': remoteResponse.provider,
              'model': remoteResponse.model,
            },
          );
        }

        return OrbitIAResponse(
          text: ChatExecutor().execute(
            message: _defaultChatResponse(message, context),
            context: context,
          ),
          source: 'local_fallback',
          intent: intent,
          latencyMs: 0,
        );

      case 'action':
        await CallExecutor().execute(
          callType: 'default',
          context: context,
        );
        return OrbitIAResponse(
          text: 'Accion ejecutada correctamente.\n${_networkAdvice(context)}',
          source: 'local_action',
          intent: intent,
          latencyMs: 0,
        );

      case 'system':
        final status = StatusExecutor().execute(
          context: context,
        );
        return OrbitIAResponse(
          text: _formatStatus(status, context),
          source: 'local_system',
          intent: intent,
          latencyMs: 0,
        );

      case 'dashboard':
        DashboardExecutor().execute(
          destination: 'default',
          context: context,
        );
        return OrbitIAResponse(
          text: 'Navegación de dashboard preparada.',
          source: 'local_dashboard',
          intent: intent,
          latencyMs: 0,
        );

      default:
        return OrbitIAResponse(
          text: _fallbackResponse(message),
          source: 'local_unknown',
          intent: 'unknown',
          latencyMs: 0,
        );
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
    final text = message.toLowerCase();
    final sector = context.recall('business_sector')?.toString();
    final priority = context.recall('priority')?.toString();

    if (text.contains('empresa') ||
        text.contains('transportadora') ||
        text.contains('logistica') ||
        text.contains('flota')) {
      final priorityHint = priority ?? 'costos, puntualidad o seguridad';
      return 'Para una empresa transportadora, Orbit IA sirve para: '
          '1) priorizar el canal correcto segun señal (chat/voz/video), '
          '2) guiar protocolos ante incidentes en ruta, '
          '3) resumir novedades operativas por turno, '
          '4) acelerar coordinacion entre conductor, despacho y cliente, '
          '5) registrar aprendizaje operativo para responder mejor cada semana. '
          'Con lo que me has contado, puedo enfocarme en $priorityHint.\n${_networkAdvice(context)}';
    }

    if (text.contains('aprender') || text.contains('mejorar')) {
      final learned = sector ?? 'tu operación';
      return 'Sí. Estoy aprendiendo progresivamente sobre $learned en esta conversación: '
          'sector, prioridades y contexto de red/clima para afinar recomendaciones.';
    }

    return 'Entendido: "$message". '
        'Puedo darte una recomendacion operativa concreta y accionable en menos de 1 minuto.\n'
        '${_networkAdvice(context)}';
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
