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

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

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
      final response = await OrbitIAService.sendMessage(
        userId: 'USER_ID', // Reemplaza con el ID real si lo tienes
        message: text,
      );
      final iaMessage = OrbitIAMessage(
        text: response,
        isUser: false,
        timestamp: DateTime.now(),
      );
      setState(() => _messages.add(iaMessage));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error en Orbit IA')),
        );
      }
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orbit IA')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final msg = _messages[i];
                return Align(
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
                );
              },
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
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
                  onPressed: _sendMessage,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
