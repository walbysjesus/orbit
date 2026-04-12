import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/auth_service.dart';
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
  final ScrollController _scrollController = ScrollController();

  final String _conversationId =
      'conv_${DateTime.now().millisecondsSinceEpoch}';

  bool _loading = false;
  String? _errorMsg;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _messages.add(
      OrbitIAMessage(
        id: _generateId(),
        conversationId: _conversationId,
        text:
            'Hola, soy Orbit IA. Escribe tu mensaje y te respondo al instante.',
        isUser: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _appendAssistantMessage(String text, {Map<String, dynamic>? metadata}) {
    final iaMessage = OrbitIAMessage(
      id: _generateId(),
      conversationId: _conversationId,
      text: text,
      isUser: false,
      metadata: metadata,
    );

    if (!mounted) return;
    setState(() => _messages.add(iaMessage));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    setState(() {
      _errorMsg = null;
      _loading = true;
    });

    final userId = _userId ?? await _getUserId();

    try {
      final response = await OrbitIAService.sendMessage(
        userId: userId,
        conversationId: _conversationId,
        message: text,
      ).timeout(const Duration(seconds: 12));
      _appendAssistantMessage(
        response,
        metadata: const {'source': 'orbit_local_ia'},
      );
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _errorMsg = 'Orbit tardó demasiado en responder. Intenta de nuevo.';
        });
      }
      _appendAssistantMessage(
        'La respuesta tardó demasiado, pero sigo aquí. Intenta con un mensaje más corto.',
        metadata: const {'source': 'timeout_fallback'},
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = 'Orbit tuvo un problema al responder 😅';
        });
      }
      _appendAssistantMessage(
        'Tu mensaje fue recibido. Tuve un problema técnico, pero puedes intentar de nuevo y te responderé.',
        metadata: const {'source': 'error_fallback'},
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<String> _getUserId() async {
    final authUser = AuthService.getCurrentUser();
    if (authUser != null) {
      _userId = authUser.uid;
      return _userId!;
    }

    if (_userId != null) return _userId!;

    const cacheKey = 'orbit_ia_local_user_id';
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(cacheKey);

    if (cached != null && cached.isNotEmpty) {
      _userId = cached;
      return _userId!;
    }

    final generated =
        'LOCAL_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    await prefs.setString(cacheKey, generated);
    _userId = generated;
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
              controller: _scrollController,
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
                      color:
                          msg.isUser ? Colors.blueAccent : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        color: msg.isUser ? Colors.white : Colors.grey.shade900,
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
                  tooltip: 'Enviar mensaje',
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
