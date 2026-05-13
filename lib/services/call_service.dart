import 'package:flutter/foundation.dart';

/// Servicio base para llamadas (audio/video). Integrar WebRTC y señalización aquí.
class CallService {
  static Future<void> startCall({
    required String remoteUserId,
    bool video = false,
  }) async {
    debugPrint('Iniciando llamada con $remoteUserId (video: $video)');
    // TODO: Integrar señalización y WebRTC
  }

  static Future<void> acceptCall(String callId) async {
    debugPrint('Aceptando llamada $callId');
    // TODO: Integrar lógica de aceptación
  }

  static Future<void> endCall(String callId) async {
    debugPrint('Finalizando llamada $callId');
    // TODO: Integrar lógica de finalización
  }
}
