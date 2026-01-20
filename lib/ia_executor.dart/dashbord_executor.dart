import '../ia_core/orbit_context.dart';

class DashboardExecutor {
  void execute({
    required String destination,
    required OrbitContext context,
  }) {
    context.rememberShortTerm('last_dashboard_route', destination);

    // Ejemplo futuro:
    // NavigationService.goTo(destination);

    return;
  }
}