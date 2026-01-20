import '../ia_core/orbit_context.dart';

enum SystemCommand {
  status,
  settings,
  security,
  diagnostics,
}

class SystemIntent {
  final SystemCommand command;

  SystemIntent(this.command);

  void applyContext(OrbitContext context) {
    context.rememberLongTerm('last_system_command', command.name);
  }

  bool isCritical() {
    return command == SystemCommand.security;
  }
}