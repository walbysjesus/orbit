import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Pantalla del historial de llamadas
/// Muestra lista de todas las llamadas realizadas y recibidas
class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _dateFormatter = DateFormat('dd MMM yyyy - HH:mm', 'es_ES');

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Historial de Llamadas')),
        body: const Center(child: Text('No autenticado')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Llamadas'),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('calls')
            .where('participants',
                arrayContains: currentUserId) // Participante en la llamada
            .orderBy('createdAt', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final calls = snapshot.data?.docs ?? [];

          if (calls.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.phone_missed, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Sin historial de llamadas',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: calls.length,
            itemBuilder: (context, index) {
              final call = calls[index];
              return _buildCallItem(context, call, currentUserId);
            },
          );
        },
      ),
    );
  }

  Widget _buildCallItem(
      BuildContext context, DocumentSnapshot call, String currentUserId) {
    final data = call.data() as Map<String, dynamic>?;
    if (data == null) return const SizedBox.shrink();

    final callerId = data['callerId'] as String? ?? '';
    final callerName = data['callerName'] as String? ?? 'Usuario';
    final isVideo = data['isVideo'] as bool? ?? false;
    final status = data['status'] as String? ?? 'unknown';
    final duration = data['duration'] as int? ?? 0;
    final createdAt = data['createdAt'] as Timestamp?;

    final isMissed = status == 'missed' || status == 'rejected';
    final isCaller = callerId == currentUserId;
    final displayName =
        isCaller ? (data['receiverName'] as String? ?? 'Usuario') : callerName;

    // Calcular duración en formato legible
    String durationStr = '';
    if (duration > 0) {
      if (duration >= 3600) {
        durationStr = '${duration ~/ 3600}h ${(duration % 3600) ~/ 60}m';
      } else if (duration >= 60) {
        durationStr = '${duration ~/ 60}m ${duration % 60}s';
      } else {
        durationStr = '${duration}s';
      }
    } else if (status != 'accepted') {
      durationStr = 'No completada';
    }

    // Determinar ícono y color
    IconData icon;
    Color iconColor;

    if (isMissed) {
      icon = Icons.phone_missed;
      iconColor = Colors.red;
    } else if (isVideo) {
      icon = Icons.videocam;
      iconColor = Colors.green;
    } else {
      icon = Icons.call;
      iconColor = Colors.blue;
    }

    return InkWell(
      onTap: () {
        // Opcional: Abrir detalles de la llamada
        _showCallDetails(context, data, displayName);
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[300]!),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar círculo con ícono
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),

              // Información principal (nombre, tipo, duración)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (isMissed)
                          Text(
                            'Llamada perdida • ',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        Text(
                          isCaller
                              ? 'Llamada realizada'
                              : 'Llamada recibida',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        if (durationStr.isNotEmpty && !isMissed) ...[
                          Text(
                            ' • ',
                            style:
                                TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          Text(
                            durationStr,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Fecha y hora a la derecha
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (createdAt != null)
                    Text(
                      _formatDate(createdAt.toDate()),
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  const SizedBox(height: 6),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCallDetails(
      BuildContext context, Map<String, dynamic> callData, String otherUserName) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Detalles de la llamada',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _detailRow('Usuario', otherUserName),
            _detailRow(
              'Tipo',
              (callData['isVideo'] as bool? ?? false) ? 'Video' : 'Audio',
            ),
            _detailRow(
              'Estado',
              (callData['status'] as String? ?? 'unknown').toUpperCase(),
            ),
            if ((callData['duration'] as int? ?? 0) > 0)
              _detailRow(
                'Duración',
                '${callData['duration']} segundos',
              ),
            _detailRow(
              'Fecha',
              _formatDate(
                  (callData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 14)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return DateFormat('HH:mm', 'es_ES').format(date);
    } else if (dateOnly == today.subtract(const Duration(days: 1))) {
      return 'Ayer';
    } else {
      return _dateFormatter.format(date);
    }
  }
}
