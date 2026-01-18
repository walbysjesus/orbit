import 'package:flutter/material.dart';
// import '../../services/dashboard_api_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _DashboardScreenBody();
  }
}

class _DashboardScreenBody extends StatefulWidget {
  @override
  State<_DashboardScreenBody> createState() => _DashboardScreenBodyState();
}

class _DashboardScreenBodyState extends State<_DashboardScreenBody> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    // _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() { _loading = false; _error = null; _data = {}; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: const Color(0xFF001F3F),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _loading
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
                          onPressed: _loadDashboard,
                        ),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Satellite usage',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Minutes used: ${_data?['minutesUsed'] ?? 0}\nMessages sent: ${_data?['messagesSent'] ?? 0}',
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      if (_data?['lastSync'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text('Last sync: ${_data!['lastSync']}', style: const TextStyle(color: Colors.white38)),
                        ),
                    ],
                  ),
      ),
    );
  }
}
