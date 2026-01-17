class OrbitIAMessage {
  /// Contenido del mensaje
  final String text;

  /// true = usuario | false = IA
  final bool isUser;

  /// Fecha y hora del mensaje
  final DateTime timestamp;

  /// Estado del mensaje (útil para red / errores)
  final OrbitIAMessageStatus status;

  OrbitIAMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.status = OrbitIAMessageStatus.sent,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Convertir a Map (DB / API / cache)
  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
    };
  }

  /// Crear desde Map (API / DB)
  factory OrbitIAMessage.fromMap(Map<String, dynamic> map) {
    return OrbitIAMessage(
      text: map['text'] ?? '',
      isUser: map['isUser'] ?? false,
      timestamp: DateTime.parse(map['timestamp']),
      status: OrbitIAMessageStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => OrbitIAMessageStatus.error,
      ),
    );
  }
}

/// Estados reales de mensaje
enum OrbitIAMessageStatus {
  sent,
  received,
  error,
}
