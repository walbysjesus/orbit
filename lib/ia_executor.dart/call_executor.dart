import '../ia_core/orbit_context.dart';

class CallExecutor {
  Future<void> execute({
    required String callType,
    required OrbitContext context,
  }) async {
    context.rememberShortTerm('last_call_type', callType);

    // Aquí SOLO se dispara la acción
    // Ejemplo futuro:
    // CallService.start(callType);

    return;
  }
}
