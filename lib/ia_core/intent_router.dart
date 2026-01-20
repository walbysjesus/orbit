enum OrbitIntentType {
  chat,
  action,
  system,
  unknown,
}

class IntentResult {
  final OrbitIntentType type;
  final String confidence;

  IntentResult(this.type, this.confidence);
}

class IntentRouter {
  IntentResult resolveIntent(String message, {String? lastIntent}) {
    final normalized = message.toLowerCase();

    if (normalized.contains('llamar') ||
        normalized.contains('iniciar llamada') ||
        normalized.contains('video')) {
      return IntentResult(OrbitIntentType.action, '0.92');
    }

    if (normalized.contains('estado') ||
        normalized.contains('configuración') ||
        normalized.contains('seguridad')) {
      return IntentResult(OrbitIntentType.system, '0.88');
    }

    if (normalized.isNotEmpty) {
      return IntentResult(OrbitIntentType.chat, '0.75');
    }

    return IntentResult(OrbitIntentType.unknown, '0.10');
  }
}