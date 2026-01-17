import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        title: const Text('History'),
        backgroundColor: const Color(0xFF001F3F),
        elevation: 0,
      ),
      body: const Center(
        child: Text(
          'No recent activity',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}
