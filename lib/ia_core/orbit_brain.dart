import 'orbit_context.dart';
import 'intent_router.dart';
import 'decision_engine.dart';

class OrbitBrain {
  final IntentRouter _intentRouter;
  final DecisionEngine _decisionEngine;

  OrbitBrain({
    IntentRouter? intentRouter,
    DecisionEngine? decisionEngine,
  })  : _intentRouter = intentRouter ?? IntentRouter(),
        _decisionEngine = decisionEngine ?? DecisionEngine();

  Decision process({
    required String message,
    required OrbitContext context,
  }) {
    final intentResult = _intentRouter.resolveIntent(
      message,
      lastIntent: context.lastIntent,
    );

    final decision = _decisionEngine.decide(
      intentResult,
      context,
    );

    context.rememberShortTerm('last_message', message);

    // 🛰️ Registrar mensaje del sistema (clima, red, seguridad)
    if (decision.systemMessage != null) {
      context.rememberShortTerm(
        'system_alert',
        decision.systemMessage!,
      );
    }

    return decision;
  }
}
