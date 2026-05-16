import 'orbit_context.dart';
import 'intent_router.dart';

enum WeatherCondition {
  clear,
  rain,
  storm,
  fog,
  extremeHeat,
  unknown,
}

class Decision {
  final OrbitIntentType intent;
  final bool requiresExecution;
  final String reason;
  final String? systemMessage;

  Decision({
    required this.intent,
    required this.requiresExecution,
    required this.reason,
    this.systemMessage,
  });
}

class DecisionEngine {
  Decision decide(
    IntentResult intentResult,
    OrbitContext context,
  ) {
    context.updateLastIntent(intentResult.type.name);

    final weather = context.weatherCondition;

    // 🌦️ Mensajes de clima pensados para conductores
    String? weatherMessage;

    switch (weather) {
      case WeatherCondition.storm:
        weatherMessage =
            '⛈️ Tormenta fuerte detectada. Se recomienda usar solo audio.';
        break;
      case WeatherCondition.rain:
        weatherMessage = '🌧️ Lluvia activa. Mantén atención en la vía.';
        break;
      case WeatherCondition.fog:
        weatherMessage = '🌫️ Niebla densa. Video deshabilitado por seguridad.';
        break;
      case WeatherCondition.extremeHeat:
        weatherMessage =
            '🔥 Temperatura extrema. Evita distracciones prolongadas.';
        break;
      default:
        break;
    }

    // 🧠 Decisión por tipo de intención
    switch (intentResult.type) {
      case OrbitIntentType.action:
        return Decision(
          intent: intentResult.type,
          requiresExecution: true,
          reason: 'User requested an actionable operation',
          systemMessage: weatherMessage,
        );

      case OrbitIntentType.system:
        return Decision(
          intent: intentResult.type,
          requiresExecution: true,
          reason: 'System-level request detected',
          systemMessage: weatherMessage,
        );

      case OrbitIntentType.chat:
        return Decision(
          intent: intentResult.type,
          requiresExecution: false,
          reason: 'Conversational response only',
          systemMessage: weatherMessage,
        );

      default:
        return Decision(
          intent: OrbitIntentType.unknown,
          requiresExecution: false,
          reason: 'Unable to classify intent',
        );
    }
  }
}
