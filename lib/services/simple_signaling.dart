import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
class SimpleSignaling {
  final String serverUrl;
  late WebSocketChannel _channel;
  Function(Map<String, dynamic>)? onMessage;

  SimpleSignaling(this.serverUrl);

  Future<void> connect() async {
    _channel = WebSocketChannel.connect(Uri.parse(serverUrl));
    // Token auth removed (backend deprecated)
    _channel.stream.listen((data) {
      final msg = jsonDecode(data);
      if (onMessage != null) onMessage!(msg);
    });
  }

  Future<void> send(Map<String, dynamic> message) async {
    // Token auth removed (backend deprecated)
    _channel.sink.add(jsonEncode(message));
  }

  void close() {
    _channel.sink.close();
  }
}
