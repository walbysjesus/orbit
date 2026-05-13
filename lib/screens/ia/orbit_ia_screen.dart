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

  String _conversationId = 'conv_bootstrap';

  bool _loading = false;
  bool _initializingIdentity = true;
  String? _errorMsg;
  String? _userId;

  int _metricsTotalIa = 0;
  int _metricsRemote = 0;
  int _metricsLocal = 0;
  int _metricsFallback = 0;
  int _metricsLatencySum = 0;
  int _metricsLatencyCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeSession();
  }

  Future<void> _initializeSession() async {
    final userId = await _getUserId();
    _conversationId = _buildConversationId(userId);
    await _loadPersistedMetrics(userId);

    if (!mounted) {
      return;
    }

    setState(() {
      _initializingIdentity = false;
      if (_messages.isEmpty) {
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
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  String _buildConversationId(String userId) {
    final normalized = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'conv_$normalized';
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
    _registerIaMetric(metadata);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading || _initializingIdentity) return;

    final userId = _userId ?? await _getUserId();
    _conversationId = _buildConversationId(userId);

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

    try {
      final response = await OrbitIAService.sendMessageDetailed(
        userId: userId,
        conversationId: _conversationId,
        message: text,
      ).timeout(const Duration(seconds: 12));
      _appendAssistantMessage(
        response.text,
        metadata: {
          'source': response.source,
          'intent': response.intent,
          'latencyMs': response.latencyMs,
          ...response.metadata,
        },
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

  String _metricKey(String suffix) {
    final uid = _userId ?? 'anon';
    return 'orbit_ia_metrics_${uid}_$suffix';
  }

  Future<void> _loadPersistedMetrics(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    _userId = userId;
    if (!mounted) return;
    setState(() {
      _metricsTotalIa = prefs.getInt(_metricKey('totalIa')) ?? 0;
      _metricsRemote = prefs.getInt(_metricKey('remote')) ?? 0;
      _metricsLocal = prefs.getInt(_metricKey('local')) ?? 0;
      _metricsFallback = prefs.getInt(_metricKey('fallback')) ?? 0;
      _metricsLatencySum = prefs.getInt(_metricKey('latencySum')) ?? 0;
      _metricsLatencyCount = prefs.getInt(_metricKey('latencyCount')) ?? 0;
    });
  }

  Future<void> _persistMetrics() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_metricKey('totalIa'), _metricsTotalIa);
    await prefs.setInt(_metricKey('remote'), _metricsRemote);
    await prefs.setInt(_metricKey('local'), _metricsLocal);
    await prefs.setInt(_metricKey('fallback'), _metricsFallback);
    await prefs.setInt(_metricKey('latencySum'), _metricsLatencySum);
    await prefs.setInt(_metricKey('latencyCount'), _metricsLatencyCount);
  }

  void _registerIaMetric(Map<String, dynamic>? metadata) {
    final source = (metadata?['source'] ?? 'unknown').toString();
    final latency = metadata?['latencyMs'];

    setState(() {
      _metricsTotalIa++;
      if (source == 'remote_llm') {
        _metricsRemote++;
      } else if (source.contains('fallback') || source.contains('error')) {
        _metricsFallback++;
      } else {
        _metricsLocal++;
      }

      if (latency is int && latency > 0) {
        _metricsLatencySum += latency;
        _metricsLatencyCount++;
      }
    });

    unawaited(_persistMetrics());
  }

  Future<void> _resetMetrics() async {
    setState(() {
      _metricsTotalIa = 0;
      _metricsRemote = 0;
      _metricsLocal = 0;
      _metricsFallback = 0;
      _metricsLatencySum = 0;
      _metricsLatencyCount = 0;
    });
    await _persistMetrics();
  }

  String _sourceLabel(Map<String, dynamic>? metadata) {
    final source = (metadata?['source'] ?? 'unknown').toString();
    switch (source) {
      case 'remote_llm':
        return 'Remota';
      case 'local_fallback':
      case 'local_system':
      case 'local_action':
      case 'local_dashboard':
      case 'local_unknown':
        return 'Local';
      case 'timeout_fallback':
        return 'Timeout';
      case 'error_fallback':
        return 'Error';
      default:
        return source;
    }
  }

  Color _sourceColor(Map<String, dynamic>? metadata) {
    final source = (metadata?['source'] ?? 'unknown').toString();
    if (source == 'remote_llm') {
      return Colors.green.shade700;
    }
    if (source.contains('fallback') || source.contains('error')) {
      return Colors.orange.shade800;
    }
    return Colors.blueGrey.shade700;
  }

  Map<String, int> _computeIaMetrics() {
    final avgLatency = _metricsLatencyCount == 0
        ? 0
        : (_metricsLatencySum ~/ _metricsLatencyCount);
    return {
      'totalIa': _metricsTotalIa,
      'remote': _metricsRemote,
      'local': _metricsLocal,
      'fallback': _metricsFallback,
      'avgLatency': avgLatency,
    };
  }

  Widget _metricChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: color, fontSize: 11),
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsStrip() {
    final metrics = _computeIaMetrics();
    if ((metrics['totalIa'] ?? 0) == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricChip(
                'IA',
                '${metrics['totalIa']}',
                Colors.blueGrey.shade700,
              ),
              _metricChip(
                'Remota',
                '${metrics['remote']}',
                Colors.green.shade700,
              ),
              _metricChip(
                'Local',
                '${metrics['local']}',
                Colors.blue.shade700,
              ),
              _metricChip(
                'Fallback',
                '${metrics['fallback']}',
                Colors.orange.shade800,
              ),
              _metricChip(
                'Latencia prom.',
                '${metrics['avgLatency']}ms',
                Colors.purple.shade700,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _resetMetrics,
              icon: const Icon(Icons.restart_alt, size: 16),
              label: const Text('Reiniciar métricas'),
            ),
          ),
        ],
      ),
    );
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
          _buildMetricsStrip(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final msg = _messages[i];
                final sourceLabel = _sourceLabel(msg.metadata);
                final sourceColor = _sourceColor(msg.metadata);
                final latency = msg.metadata?['latencyMs'];
                return Align(
                  alignment:
                      msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: msg.isUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Container(
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
                      if (msg.isFromIA)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6, left: 4),
                          child: Text(
                            latency is int
                                ? '$sourceLabel · ${latency}ms'
                                : sourceLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: sourceColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
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
                    enabled: !_initializingIdentity,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  tooltip: 'Enviar mensaje',
                  onPressed:
                      (_loading || _initializingIdentity) ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
