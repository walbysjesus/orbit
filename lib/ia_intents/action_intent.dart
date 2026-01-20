import '../ia_core/orbit_context.dart';

class ActionIntent {
  final String command;
  final Map<String, dynamic> parameters;

  ActionIntent({
    required this.command,
    Map<String, dynamic>? parameters,
  }) : parameters = parameters ?? {};

  void applyContext(OrbitContext context) {
    context.rememberShortTerm('last_action', command);
    context.rememberShortTerm('action_params', parameters);
  }

  bool requiresExecution() => true;
}