import 'short_term_memory.dart';
import 'long_term_memory.dart';

class ConversationState {
  final String conversationId;
  final String userId;

  final ShortTermMemory shortTermMemory;
  final LongTermMemory longTermMemory;

  String? activeIntent;
  DateTime lastInteraction;

  ConversationState({
    required this.conversationId,
    required this.userId,
    ShortTermMemory? shortTermMemory,
    LongTermMemory? longTermMemory,
    this.activeIntent,
    DateTime? lastInteraction,
  })  : shortTermMemory = shortTermMemory ?? ShortTermMemory(),
        longTermMemory = longTermMemory ?? LongTermMemory(),
        lastInteraction = lastInteraction ?? DateTime.now();

  void updateIntent(String intent) {
    activeIntent = intent;
    lastInteraction = DateTime.now();
  }

  Map<String, dynamic> snapshot() {
    return {
      'conversationId': conversationId,
      'userId': userId,
      'activeIntent': activeIntent,
      'lastInteraction': lastInteraction.toIso8601String(),
      'shortTerm': shortTermMemory.snapshot(),
      'longTerm': longTermMemory.export(),
    };
  }
}