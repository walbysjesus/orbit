import 'dart:async';

/// Helper para reintentos automáticos con backoff exponencial.
/// - Ejecuta una función asíncrona y reintenta si falla, hasta un máximo de intentos.
/// - Útil para robustecer llamadas a red y servicios externos.
Future<T> retry<T>(
  Future<T> Function() action, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(milliseconds: 500),
  Duration? maxDelay,
  bool Function(Object error)? retryIf,
}) async {
  int attempt = 0;
  Duration delay = initialDelay;
  while (true) {
    try {
      return await action();
    } catch (e) {
      attempt++;
      if (attempt >= maxAttempts || (retryIf != null && !retryIf(e))) {
        rethrow;
      }
      await Future.delayed(delay);
      delay = Duration(
          milliseconds: (delay.inMilliseconds * 2)
              .clamp(0, maxDelay?.inMilliseconds ?? 4000));
    }
  }
}
