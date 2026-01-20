class OrbitContext {
  final String conversationId;
  final String userId;

  final Map<String, dynamic> shortTermMemory;
  final Map<String, dynamic> longTermMemory;

  String? lastIntent;
  DateTime lastInteraction;

  OrbitContext({
    required this.conversationId,
    required this.userId,
    Map<String, dynamic>? shortTermMemory,
    Map<String, dynamic>? longTermMemory,
    this.lastIntent,
    DateTime? lastInteraction,
  })  : shortTermMemory = shortTermMemory ?? {},
        longTermMemory = longTermMemory ?? {},
        lastInteraction = lastInteraction ?? DateTime.now();

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