import 'package:flutter/material.dart';
import '../../services/history_api_service.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _HistoryScreenBody();
  }
}

class _HistoryScreenBody extends StatefulWidget {
  @override
  State<_HistoryScreenBody> createState() => _HistoryScreenBodyState();
}

class _HistoryScreenBodyState extends State<_HistoryScreenBody> {
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _visible = [];
  bool _loading = true;
  String? _error;
  String? _feedbackMsg;
  String _activeFilter = 'todos';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
      _feedbackMsg = null;
    });
    try {
      final data = await HistoryApiService.fetchHistory();
      setState(() {
        _history = data;
        _applyFilter(_activeFilter);
        _loading = false;
        if (_history.isEmpty) {
          _feedbackMsg = 'No hay actividad reciente.';
        }
      });
    } catch (e) {
      setState(() {
        _error = 'No se pudo cargar el historial. Verifica tu conexión.';
        _loading = false;
      });
    }
  }

  void _applyFilter(String filter) {
    _activeFilter = filter;
    if (filter == 'todos') {
      _visible = List.from(_history);
      return;
    }

    _visible = _history.where((item) {
      final type = _normalizeType(item['type']?.toString() ?? '');
      return type == filter;
    }).toList();
  }

  String _normalizeType(String raw) {
    final t = raw.toLowerCase().trim();
    if (t.contains('video')) return 'video';
    if (t.contains('llamada') || t.contains('call') || t.contains('voz')) {
      return 'llamada';
    }
    if (t.contains('chat') || t.contains('mensaje')) return 'chat';
    return 'otros';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8FD),
      appBar: AppBar(
        title: const Text('Historial'),
        backgroundColor: const Color(0xFFFFFFFF),
        foregroundColor: const Color(0xFF0A4D8F),
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0A4D8F)))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 48),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 16)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent),
                        onPressed: _loadHistory,
                      ),
                    ],
                  ),
                )
              : _history.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline,
                              color: Color(0xFF5F7890), size: 48),
                          const SizedBox(height: 12),
                          Text(_feedbackMsg ?? 'No hay actividad reciente',
                              style: const TextStyle(
                                  color: Color(0xFF4D6880), fontSize: 16)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadHistory,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFFFF),
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: const Color(0xFFC9DEEE)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Actividad reciente',
                                  style: TextStyle(
                                    color: Color(0xFF123A5B),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _HistoryFilterChip(
                                      label: 'Todos',
                                      selected: _activeFilter == 'todos',
                                      onTap: () {
                                        setState(() => _applyFilter('todos'));
                                      },
                                    ),
                                    _HistoryFilterChip(
                                      label: 'Chat',
                                      selected: _activeFilter == 'chat',
                                      onTap: () {
                                        setState(() => _applyFilter('chat'));
                                      },
                                    ),
                                    _HistoryFilterChip(
                                      label: 'Llamadas',
                                      selected: _activeFilter == 'llamada',
                                      onTap: () {
                                        setState(() => _applyFilter('llamada'));
                                      },
                                    ),
                                    _HistoryFilterChip(
                                      label: 'Video',
                                      selected: _activeFilter == 'video',
                                      onTap: () {
                                        setState(() => _applyFilter('video'));
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_visible.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFFFF),
                                borderRadius: BorderRadius.circular(14),
                                border:
                                    Border.all(color: const Color(0xFFC9DEEE)),
                              ),
                              child: const Text(
                                'No hay eventos en este filtro.',
                                style: TextStyle(color: Color(0xFF4D6880)),
                              ),
                            ),
                          ..._visible.map((item) {
                            final type =
                                _normalizeType(item['type']?.toString() ?? '');
                            final style = _historyStyle(type);
                            return Semantics(
                              label: 'Elemento de historial',
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFFFFFF),
                                      Color(0xFFEAF5FE)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: const Color(0xFFC9DEEE)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: style.color.withAlpha(35),
                                            border: Border.all(
                                              color: style.color.withAlpha(170),
                                            ),
                                          ),
                                          child: Icon(style.icon,
                                              color: style.color, size: 19),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            item['title'] ?? 'Sin título',
                                            style: const TextStyle(
                                              color: Color(0xFF123A5B),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          item['date']?.toString() ?? '',
                                          style: const TextStyle(
                                            color: Color(0xFF6D8599),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: style.color.withAlpha(35),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            item['type']?.toString() ?? 'otro',
                                            style: TextStyle(
                                              color: style.color,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        TextButton.icon(
                                          onPressed: () {},
                                          icon: const Icon(
                                              Icons.chat_bubble_outline,
                                              size: 16),
                                          label: const Text('Abrir chat'),
                                        ),
                                        TextButton.icon(
                                          onPressed: () {},
                                          icon:
                                              const Icon(Icons.call, size: 16),
                                          label: const Text('Llamar'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
    );
  }

  _HistoryStyle _historyStyle(String type) {
    switch (type) {
      case 'chat':
        return const _HistoryStyle(
          icon: Icons.chat_bubble_rounded,
          color: Color(0xFF56B7FF),
        );
      case 'llamada':
        return const _HistoryStyle(
          icon: Icons.call_rounded,
          color: Color(0xFFFFB46A),
        );
      case 'video':
        return const _HistoryStyle(
          icon: Icons.videocam_rounded,
          color: Color(0xFF53D2A6),
        );
      default:
        return const _HistoryStyle(
          icon: Icons.history,
          color: Color(0xFF9AB5CF),
        );
    }
  }
}

class _HistoryFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _HistoryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2FA0FF).withAlpha(35)
              : const Color(0xFFEAF3FB),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF4BB8FF) : const Color(0xFFB8D1E5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF0A4D8F) : const Color(0xFF4D6880),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _HistoryStyle {
  final IconData icon;
  final Color color;

  const _HistoryStyle({required this.icon, required this.color});
}
