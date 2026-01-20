import 'orbit_context.dart';
import 'intent_router.dart';

class Decision {
  final OrbitIntentType intent;
  final bool requiresExecution;
  final String reason;

  Decision({
    required this.intent,
    required this.requiresExecution,
    required this.reason,
  });
}

class DecisionEngine {
  Decision decide(
    IntentResult intentResult,
    OrbitContext context,
  ) {
    context.updateLastIntent(intentResult.type.name);

    switch (intentResult.type) {
      case OrbitIntentType.action:
        return Decision(
          intent: intentResult.type,
          requiresExecution: true,
          reason: 'User requested an actionable operation',
        );

      case OrbitIntentType.system:
        return Decision(
          intent: intentResult.type,
          requiresExecution: true,
          reason: 'System-level request detected',
        );

      case OrbitIntentType.chat:
        return Decision(
          intent: intentResult.type,
          requiresExecution: false,
          reason: 'Conversational response only',
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