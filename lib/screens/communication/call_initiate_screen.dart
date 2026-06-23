import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/call_service.dart';

/// Pantalla para iniciar nuevas llamadas
class CallInitiateScreen extends StatefulWidget {
  const CallInitiateScreen({super.key});

  @override
  State<CallInitiateScreen> createState() => _CallInitiateScreenState();
}

class _CallInitiateScreenState extends State<CallInitiateScreen> {
  final _callService = CallService();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _onlineUsers = [];
  bool _isLoading = true;
  bool _isVideoEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadOnlineUsers();
  }

  void _loadOnlineUsers() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    _firestore
        .collection('users')
        .where('uid', isNotEqualTo: currentUser.uid)
        .where('isOnline', isEqualTo: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _onlineUsers = snapshot.docs
            .map((doc) => {
                  'uid': doc.id,
                  'displayName': doc['displayName'] ?? 'Usuario',
                  'photoURL': doc['photoURL'],
                  'status': doc['status'] ?? '',
                  'lastSeen': doc['lastSeen'],
                })
            .toList();
        _isLoading = false;
      });
    }, onError: (e) {
      setState(() => _isLoading = false);
      _showError('Error al cargar usuarios: $e');
    });
  }

  Future<void> _initiateCall(
      String remoteUserId, String remoteDisplayName) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Iniciando llamada con $remoteDisplayName...')),
      );

      final roomId = await _callService.initiateCall(
        remoteUserId: remoteUserId,
        isVideo: _isVideoEnabled,
      );

      if (!mounted) return;

      // Navegar a pantalla de llamada
      Navigator.of(context).pushNamed(
        '/video-call',
        arguments: {
          'roomId': roomId,
          'remoteUserId': remoteUserId,
          'remoteDisplayName': remoteDisplayName,
          'isVideo': _isVideoEnabled,
          'isCaller': true,
        },
      );
    } catch (e) {
      String errorMsg = 'Error: $e';
      
      // ✅ Mostrar error específico para TURN
      if (e.toString().contains('PRODUCTION BLOCKED')) {
        errorMsg = 'Llamadas no disponibles: Servidor TURN no configurado.\n'
                   'Contacta al administrador de la aplicación.';
      } else if (e.toString().contains('authenticated')) {
        errorMsg = 'Por favor inicia sesión primero.';
      } else if (e.toString().contains('progreso')) {
        errorMsg = 'Ya hay una llamada en progreso.';
      }
      
      _showError(errorMsg);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciar Llamada'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Tipo de llamada
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                Icon(
                  _isVideoEnabled ? Icons.videocam : Icons.call,
                  color: Colors.blue,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isVideoEnabled ? 'Llamada de Video' : 'Llamada de Voz',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Switch(
                  value: _isVideoEnabled,
                  onChanged: (value) {
                    setState(() => _isVideoEnabled = value);
                  },
                ),
              ],
            ),
          ),
          // Lista de usuarios
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _onlineUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hay usuarios en línea',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: _onlineUsers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final user = _onlineUsers[index];
                          return _buildUserCard(user);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    return Card(
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: Colors.blue[100],
          backgroundImage:
              user['photoURL'] != null ? NetworkImage(user['photoURL']) : null,
          child: user['photoURL'] == null
              ? const Icon(Icons.person, color: Colors.blue)
              : null,
        ),
        title: Text(
          user['displayName'] ?? 'Usuario',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          user['status'] ?? 'En línea',
          style: const TextStyle(fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: () => _initiateCall(
                user['uid'],
                user['displayName'],
              ),
              icon: Icon(
                _isVideoEnabled ? Icons.videocam : Icons.call,
              ),
              label: Text(
                _isVideoEnabled ? 'Video' : 'Llamar',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _callService.dispose();
    super.dispose();
  }
}
