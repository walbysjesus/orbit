class OrbitIAMessage {
  /// ID único del mensaje
  final String id;

  /// ID de la conversación (contexto)
  final String conversationId;

  /// Contenido del mensaje
  final String text;

  /// true = usuario | false = IA
  final bool isUser;

  /// Fecha y hora del mensaje
  final DateTime timestamp;

  /// Estado del mensaje (red / errores / retries)
  final OrbitIAMessageStatus status;

  /// Metadatos dinámicos (intención, confianza, fuente, etc.)
  final Map<String, dynamic>? metadata;

  OrbitIAMessage({
    required this.id,
    required this.conversationId,
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.status = OrbitIAMessageStatus.sent,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Helper semántico
  bool get isFromIA => !isUser;

  /// Crear copia modificada (inmutable)
  OrbitIAMessage copyWith({
    String? text,
    bool? isUser,
    DateTime? timestamp,
    OrbitIAMessageStatus? status,
    Map<String, dynamic>? metadata,
  }) {
    return OrbitIAMessage(
      id: id,
      conversationId: conversationId,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convertir a Map (DB / API / cache)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversationId': conversationId,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'metadata': metadata,
    };
  }

  /// Crear desde Map (API / DB)
  factory OrbitIAMessage.fromMap(Map<String, dynamic> map) {
    DateTime parsedTime;
    try {
      parsedTime = DateTime.parse(map['timestamp']);
    } catch (_) {
      parsedTime = DateTime.now();
    }

    return OrbitIAMessage(
      id: map['id'] ?? '',
      conversationId: map['conversationId'] ?? '',
      text: map['text'] ?? '',
      isUser: map['isUser'] ?? false,
      timestamp: parsedTime,
      status: OrbitIAMessageStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => OrbitIAMessageStatus.error,
      ),
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(map['metadata'])
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrbitIAMessage && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Estados reales de mensaje
enum OrbitIAMessageStatus {
  sent,
  received,
  error,
}