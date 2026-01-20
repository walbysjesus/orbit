import '../ia_core/orbit_context.dart';

class StatusExecutor {
  Map<String, dynamic> execute({
    required OrbitContext context,
  }) {
    final status = {
      'lastIntent': context.lastIntent,
      'lastInteraction': context.lastInteraction.toIso8601String(),
      'shortTermMemorySize': context.shortTermMemory.length,
      'longTermMemorySize': context.longTermMemory.length,
    };

    context.rememberShortTerm('last_status_check', DateTime.now());

    return status;
  }
}