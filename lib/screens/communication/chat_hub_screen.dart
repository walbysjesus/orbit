import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../home/contacts_screen.dart';
import 'chat_screen.dart' as chat;

class ChatHubScreen extends StatefulWidget {
  const ChatHubScreen({super.key});

  @override
  State<ChatHubScreen> createState() => _ChatHubScreenState();
}

class _ChatHubScreenState extends State<ChatHubScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> _openNewChat() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const ContactsScreen(initialAction: ContactActionType.chat),
      ),
    );
    if (mounted) setState(() {});
  }

  void _openChat(String remoteUid, String displayName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => chat.ChatScreen(
          remoteUserId: remoteUid,
          initialContactName: displayName,
        ),
      ),
    );
  }

  Future<List<_ChatPreview>> _loadChats() async {
    final uid = AuthService.getCurrentUser()?.uid;
    if (uid == null) return const [];

    final roomSnap = await _db
        .collection('chatRooms')
        .where('participants', arrayContains: uid)
        .limit(50)
        .get();

    final previews = <_ChatPreview>[];

    for (final room in roomSnap.docs) {
      final data = room.data();
      final participants =
          List<String>.from((data['participants'] as List?) ?? const []);
      final remoteUid = participants.firstWhere(
        (id) => id != uid,
        orElse: () => '',
      );
      if (remoteUid.isEmpty) continue;

      final userSnap =
          await _db.collection('users_public').doc(remoteUid).get();
      final userData = userSnap.data();
      final fullName = (userData?['fullName'] as String?)?.trim();
      final displayName =
          (fullName == null || fullName.isEmpty) ? remoteUid : fullName;

      final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate() ??
          (data['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0);

      previews.add(
        _ChatPreview(
          roomId: room.id,
          remoteUid: remoteUid,
          displayName: displayName,
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
        title: const Text('Chats'),
      ),
      body: FutureBuilder<List<_ChatPreview>>(
        future: _loadChats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final chats = snapshot.data ?? const [];
          if (chats.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.forum_outlined,
                        size: 52, color: Color(0xFF7A8CA0)),
                    const SizedBox(height: 12),
                    const Text(
                      'Aún no tienes chats activos',
                      style: TextStyle(
                        color: Color(0xFF16324F),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Inicia una conversación para verla aquí.',
                      style: TextStyle(color: Color(0xFF6D7F92)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _openNewChat,
                      icon: const Icon(Icons.add_comment),
                      label: const Text('Nuevo chat'),
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
              itemCount: chats.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final item = chats[i];
                return ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFD9EBFA),
                    child: Text(
                      item.displayName.isEmpty
                          ? '?'
                          : item.displayName[0].toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF0A4D8F),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  title: Text(
                    item.displayName,
                    style: const TextStyle(
                      color: Color(0xFF16324F),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Última actividad: ${_formatDate(item.updatedAt)}',
                    style:
                        const TextStyle(color: Color(0xFF6D7F92), fontSize: 12),
                  ),
                  trailing:
                      const Icon(Icons.chevron_right, color: Color(0xFF7A8CA0)),
                  onTap: () => _openChat(item.remoteUid, item.displayName),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewChat,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo chat'),
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
}

class _ChatPreview {
  final String roomId;
  final String remoteUid;
  final String displayName;
  final DateTime updatedAt;

  const _ChatPreview({
    required this.roomId,
    required this.remoteUid,
    required this.displayName,
    required this.updatedAt,
  });
}
