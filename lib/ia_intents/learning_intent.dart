import '../ia_core/orbit_context.dart';

class LearningIntent {
  final String signal;
  final dynamic value;

  LearningIntent({
    required this.signal,
    required this.value,
  });

  void persist(OrbitContext context) {
    context.rememberLongTerm(signal, value);
  }

  bool isValid() {
    return signal.isNotEmpty;
  }
}