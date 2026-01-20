import 'decision_engine.dart';

class OrbitContext {
  final String conversationId;
  final String userId;

  final Map<String, dynamic> shortTermMemory;
  final Map<String, dynamic> longTermMemory;

  String? lastIntent;
  DateTime lastInteraction;

  // Propiedades opcionales para contexto extendido (clima y red)
  final WeatherCondition? _weatherCondition;
  final String? _networkQuality;

  OrbitContext({
    required this.conversationId,
    required this.userId,
    Map<String, dynamic>? shortTermMemory,
    Map<String, dynamic>? longTermMemory,
    this.lastIntent,
    DateTime? lastInteraction,
    WeatherCondition? weatherCondition,
    String? networkQuality,
  })  : shortTermMemory = shortTermMemory ?? {},
        longTermMemory = longTermMemory ?? {},
        lastInteraction = lastInteraction ?? DateTime.now(),
        _weatherCondition = weatherCondition,
        _networkQuality = networkQuality;
  // Getters seguros para compatibilidad con lógica existente
  WeatherCondition get weatherCondition => _weatherCondition ?? WeatherCondition.unknown;
  String get networkQuality => _networkQuality ?? 'unknown';

  void updateLastIntent(String intent) {
    lastIntent = intent;
    lastInteraction = DateTime.now();
  }

  void rememberShortTerm(String key, dynamic value) {
    shortTermMemory[key] = value;
  }

  void rememberLongTerm(String key, dynamic value) {
    longTermMemory[key] = value;
  }

  dynamic recall(String key) {
    return shortTermMemory[key] ?? longTermMemory[key];
  }
}