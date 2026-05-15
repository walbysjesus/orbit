import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../home/contacts_screen.dart';
import 'video_call_screen.dart';

class VideoHubScreen extends StatefulWidget {
  const VideoHubScreen({super.key});

  @override
  State<VideoHubScreen> createState() => _VideoHubScreenState();
}

class _VideoHubScreenState extends State<VideoHubScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> _openNewVideoCall() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const ContactsScreen(initialAction: ContactActionType.videoCall),
      ),
    );
    if (mounted) setState(() {});
  }

  void _startVideoCall(String remoteUid) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          remoteUserId: remoteUid,
          isCaller: true,
          audioOnly: true, // SIEMPRE inicia en solo audio
        ),
      ),
    );
  }

  Future<List<_CallPreview>> _loadRecentCalls() async {
    final uid = AuthService.getCurrentUser()?.uid;
    if (uid == null) return const [];

    final asCaller = await _db
        .collection('callSessions')
        .where('callerId', isEqualTo: uid)
        .limit(25)
        .get();

    final asCallee = await _db
        .collection('callSessions')
        .where('calleeId', isEqualTo: uid)
        .limit(25)
        .get();

    final merged = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in [...asCaller.docs, ...asCallee.docs]) {
      merged[doc.id] = doc;
    }

    final previews = <_CallPreview>[];
    for (final doc in merged.values) {
      final data = doc.data();
      final callerId = (data['callerId'] as String?) ?? '';
      final calleeId = (data['calleeId'] as String?) ?? '';
      final remoteUid = callerId == uid ? calleeId : callerId;
      if (remoteUid.isEmpty || remoteUid == uid) continue;

      final userSnap =
          await _db.collection('users_public').doc(remoteUid).get();
      final userData = userSnap.data();
      final fullName = (userData?['fullName'] as String?)?.trim();
      final displayName =
          (fullName == null || fullName.isEmpty) ? remoteUid : fullName;

      final status = (data['status'] as String?) ?? 'unknown';
      final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate() ??
          (data['startedAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0);

      previews.add(
        _CallPreview(
          remoteUid: remoteUid,
          displayName: displayName,
          status: status,
          updatedAt: updatedAt,
        ),
      );
    }

    previews.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return previews;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8FD),
      appBar: AppBar(
        title: const Text('Video'),
      ),
      body: FutureBuilder<List<_CallPreview>>(
        future: _loadRecentCalls(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final calls = snapshot.data ?? const [];
          if (calls.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_outlined,
                        size: 52, color: Color(0xFF7A8CA0)),
                    const SizedBox(height: 12),
                    const Text(
                      'Aún no tienes videollamadas',
                      style: TextStyle(
                        color: Color(0xFF16324F),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Inicia una videollamada para verla aquí.',
                      style: TextStyle(color: Color(0xFF6D7F92)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _openNewVideoCall,
                      icon: const Icon(Icons.video_call),
                      label: const Text('Nueva videollamada'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              if (mounted) setState(() {});
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
              itemCount: calls.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final item = calls[i];
                return ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFD9EBFA),
                    child: const Icon(Icons.videocam, color: Color(0xFF0A4D8F)),
                  ),
                  title: Text(
                    item.displayName,
                    style: const TextStyle(
                      color: Color(0xFF16324F),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${_statusLabel(item.status)} · ${_formatDate(item.updatedAt)}',
                    style:
                        const TextStyle(color: Color(0xFF6D7F92), fontSize: 12),
                  ),
                  trailing: IconButton(
                    tooltip: 'Videollamar',
                    icon:
                        const Icon(Icons.video_call, color: Color(0xFF0A4D8F)),
                    onPressed: () => _startVideoCall(item.remoteUid),
                  ),
                  onTap: () => _startVideoCall(item.remoteUid),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewVideoCall,
        icon: const Icon(Icons.add),
        label: const Text('Nueva videollamada'),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'ringing':
        return 'Timbrando';
      case 'accepted':
        return 'Conectada';
      case 'ended':
        return 'Finalizada';
      case 'rejected':
        return 'Rechazada';
      default:
        return 'Actividad';
    }
  }
}

class _CallPreview {
  final String remoteUid;
  final String displayName;
  final String status;
  final DateTime updatedAt;

  const _CallPreview({
    required this.remoteUid,
    required this.displayName,
    required this.status,
    required this.updatedAt,
  });
}
