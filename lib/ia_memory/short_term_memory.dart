class ShortTermMemory {
  final Map<String, dynamic> _memory = {};

  void store(String key, dynamic value) {
    _memory[key] = value;
  }

  dynamic recall(String key) {
    return _memory[key];
  }

  void remove(String key) {
    _memory.remove(key);
  }

  void clear() {
    _memory.clear();
  }

  Map<String, dynamic> snapshot() {
    return Map.unmodifiable(_memory);
  }
}