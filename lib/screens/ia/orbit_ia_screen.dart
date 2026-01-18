import 'package:flutter/material.dart';
import '../../services/orbit_ia_service.dart';
import '../../models/orbit_ia_message.dart';


class OrbitIAScreen extends StatefulWidget {
  const OrbitIAScreen({super.key});

  @override
  State<OrbitIAScreen> createState() => _OrbitIAScreenState();
}

class _OrbitIAScreenState extends State<OrbitIAScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<OrbitIAMessage> _messages = [];
  bool _loading = false;
  String? _errorMsg;
  String? _userId;

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() { _errorMsg = null; });
    final userMessage = OrbitIAMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
    setState(() {
      _messages.add(userMessage);
      _loading = true;
      _controller.clear();
    });
    try {
      final userId = _userId ?? await _getUserId();
      final response = await OrbitIAService.sendMessage(
        userId: userId,
        message: text,
      );
      final iaMessage = OrbitIAMessage(
        text: response,
        isUser: false,
        timestamp: DateTime.now(),
      );
      setState(() => _messages.add(iaMessage));
    } catch (e) {
      setState(() { _errorMsg = 'Error en Orbit IA: ${e.toString().replaceAll("Exception:", "").trim()}'; });
    }
    if (mounted) {
      setState(() => _loading = false);
    }

  }

  Future<String> _getUserId() async {
    // Aquí deberías obtener el userId real del usuario autenticado
    // Ejemplo: final user = await AuthService.getCurrentUser(); return user?.orbitId ?? 'USER_ID';
    return 'USER_ID';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orbit IA')),
      body: Column(
        children: [
          if (_errorMsg != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_errorMsg!, style: const TextStyle(color: Colors.redAccent))),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final msg = _messages[i];
                return Semantics(
                  label: msg.isUser ? 'Mensaje enviado' : 'Respuesta IA',
                  child: Align(
                    alignment:
                        msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: msg.isUser
                            ? Colors.blue
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        msg.text,
                        style: TextStyle(
                          color: msg.isUser ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_loading)
            const LinearProgressIndicator(minHeight: 3, color: Colors.blueAccent),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration:
                        const InputDecoration(hintText: 'Habla con Orbit IA'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _loading ? null : _sendMessage,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
