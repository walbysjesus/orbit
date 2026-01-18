class OrbitIAService {
  // Backend removed. This is a stub for local-only or Firebase-based logic.
  static Future<String> sendMessage({
    required String userId,
    required String message,
  }) async {
    // Lógica local simulada para IA en español
    if (message.toLowerCase().contains('hola')) {
      return "¡Hola! ¿En qué puedo ayudarte hoy?";
    } else if (message.toLowerCase().contains('adiós')) {
      return "¡Hasta luego! Si necesitas algo más, aquí estaré.";
    } else if (message.trim().isEmpty) {
      return "Por favor, escribe un mensaje para que pueda ayudarte.";
    } else {
      return "[Respuesta IA simulada]: Recibí tu mensaje: '$message'";
    }
  }
}
