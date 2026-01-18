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
  bool _loading = true;
  String? _error;
  String? _feedbackMsg;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() { _loading = true; _error = null; _feedbackMsg = null; });
    try {
      final data = await HistoryApiService.fetchHistory();
      setState(() {
        _history = data;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        title: const Text('Historial'),
        backgroundColor: const Color(0xFF001F3F),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 16)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
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
                          Icon(Icons.info_outline, color: Colors.white70, size: 48),
                          const SizedBox(height: 12),
                          Text(_feedbackMsg ?? 'No hay actividad reciente', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _history.length,
                      itemBuilder: (_, i) {
                        final item = _history[i];
                        return Semantics(
                          label: 'Elemento de historial',
                          child: ListTile(
                            leading: Icon(Icons.history, color: Colors.white),
                            title: Text(item['title'] ?? 'Sin título', style: const TextStyle(color: Colors.white)),
                            subtitle: Text(item['date'] ?? '', style: const TextStyle(color: Colors.white70)),
                            trailing: Text(item['type'] ?? '', style: const TextStyle(color: Colors.blueAccent)),
                          ),
                        );
                      },
                    ),
    );
  }
}
