import 'dart:math';
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

  final String _conversationId =
      'conv_${DateTime.now().millisecondsSinceEpoch}';

  bool _loading = false;
  String? _errorMsg;
  String? _userId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;

    setState(() {
      _errorMsg = null;
      _loading = true;
    });

    final userId = _userId ?? await _getUserId();

    final userMessage = OrbitIAMessage(
      id: _generateId(),
      conversationId: _conversationId,
      text: text,
      isUser: true,
    );

    setState(() {
      _messages.add(userMessage);
      _controller.clear();
    });

    try {
      final response = await OrbitIAService.sendMessage(
        userId: userId,
        conversationId: _conversationId,
        message: text,
      );

      final iaMessage = OrbitIAMessage(
        id: _generateId(),
        conversationId: _conversationId,
        text: response,
        isUser: false,
        metadata: const {
          'source': 'orbit_local_ia',
        },
      );

      if (mounted) {
        setState(() => _messages.add(iaMessage));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = 'Orbit tuvo un problema al responder 😅';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<String> _getUserId() async {
    // En el futuro: AuthService / Firebase / JWT
    _userId ??= 'USER_${DateTime.now().millisecondsSinceEpoch}';
    return _userId!;
  }

  String _generateId() {
    final rand = Random().nextInt(999999);
    return 'msg_${DateTime.now().millisecondsSinceEpoch}_$rand';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orbit IA')),
      body: Column(
        children: [
          if (_errorMsg != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMsg!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final msg = _messages[i];
                return Align(
                  alignment: msg.isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: msg.isUser
                          ? Colors.blueAccent
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        color: msg.isUser
                            ? Colors.white
                            : Colors.grey.shade900,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 3),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Habla con Orbit…',
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _loading ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
