class LongTermMemory {
  final Map<String, dynamic> _memory = {};

  void store(String key, dynamic value) {
    _memory[key] = value;
  }

  dynamic recall(String key) {
    return _memory[key];
  }

  bool contains(String key) {
    return _memory.containsKey(key);
  }

  Map<String, dynamic> export() {
    return Map.unmodifiable(_memory);
  }
}