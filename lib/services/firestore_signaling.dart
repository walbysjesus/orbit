import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Señalización WebRTC basada en Firestore.
/// Reemplaza el servidor WebSocket — funciona con cualquier dispositivo físico.
///
/// Estructura en Firestore:
///   /callSignaling/{roomId}
///     - callerJoinedAt: Timestamp
///     - calleeJoinedAt: Timestamp
///     - sdpOffer:  { type: 'offer',  sdp: string }
///     - sdpAnswer: { type: 'answer', sdp: string }
///   /callSignaling/{roomId}/callerCandidates/{id}  — ICE del caller
///   /callSignaling/{roomId}/calleeCandidates/{id}  — ICE del callee
class FirestoreSignaling {
  final String roomId;
  final bool isCaller;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _connected = false;
  bool _offerEmitted = false;
  bool _answerEmitted = false;
  bool _peerJoinedEmitted = false;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roomSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _candidateSub;

  Function(Map<String, dynamic>)? onMessage;
  Function(String)? onError;
  Function(bool)? onConnectionChanged;

  FirestoreSignaling({required this.roomId, required this.isCaller});

  // ─────────────────────────────────────────────────────────
  // CONNECT
  // ─────────────────────────────────────────────────────────

  Future<void> connect() async {
    if (_connected) return;
    _connected = true;
    onConnectionChanged?.call(true);

    try {
      // Registrar presencia en la sala
      await _db.collection('callSignaling').doc(roomId).set(
        {
          isCaller ? 'callerJoinedAt' : 'calleeJoinedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Escuchar cambios del documento de sala (SDP + presencia)
      _roomSub = _db
          .collection('callSignaling')
          .doc(roomId)
          .snapshots()
          .listen(_onRoomSnapshot, onError: _onStreamError);

      // Escuchar candidatos ICE del otro extremo
      final remoteColl = isCaller ? 'calleeCandidates' : 'callerCandidates';
      _candidateSub = _db
          .collection('callSignaling')
          .doc(roomId)
          .collection(remoteColl)
          .snapshots()
          .listen(_onCandidatesSnapshot, onError: _onStreamError);
    } catch (e) {
      _connected = false;
      onConnectionChanged?.call(false);
      onError?.call('Error al conectar señalización: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────
  // LISTENERS
  // ─────────────────────────────────────────────────────────

  void _onRoomSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (!snap.exists) return;
    final data = snap.data()!;

    if (isCaller) {
      // Caller: espera que callee se una → emite 'peer-joined'
      if (data['calleeJoinedAt'] != null && !_peerJoinedEmitted) {
        _peerJoinedEmitted = true;
        onMessage?.call({'type': 'peer-joined'});
      }
      // Caller: espera la respuesta SDP del callee
      if (data['sdpAnswer'] != null && !_answerEmitted) {
        _answerEmitted = true;
        final sdpAnswer = data['sdpAnswer'] as Map<String, dynamic>;
        onMessage?.call({
          'type': 'answer',
          'sdp': sdpAnswer['sdp'] as String?,
        });
      }
    } else {
      // Callee: espera la oferta SDP del caller
      if (data['sdpOffer'] != null && !_offerEmitted) {
        _offerEmitted = true;
        final sdpOffer = data['sdpOffer'] as Map<String, dynamic>;
        onMessage?.call({
          'type': 'offer',
          'sdp': sdpOffer['sdp'] as String?,
        });
      }
    }
  }

  void _onCandidatesSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    for (final change in snap.docChanges) {
      if (change.type == DocumentChangeType.added) {
        final d = change.doc.data();
        if (d != null) {
          onMessage?.call({'type': 'candidate', 'candidate': d});
        }
      }
    }
  }

  void _onStreamError(Object error) {
    debugPrint('FirestoreSignaling error: $error');
    onError?.call('Error en señalización Firestore');
  }

  // ─────────────────────────────────────────────────────────
  // SEND
  // ─────────────────────────────────────────────────────────

  Future<void> send(Map<String, dynamic> message) async {
    if (!_connected) return;
    final type = message['type'] as String?;

    switch (type) {
      case 'join':
        // Ya manejado en connect()
        break;

      case 'offer':
        await _db.collection('callSignaling').doc(roomId).set(
          {
            'sdpOffer': {'type': 'offer', 'sdp': message['sdp']},
          },
          SetOptions(merge: true),
        );
        break;

      case 'answer':
        await _db.collection('callSignaling').doc(roomId).set(
          {
            'sdpAnswer': {'type': 'answer', 'sdp': message['sdp']},
          },
          SetOptions(merge: true),
        );
        break;

      case 'candidate':
        final myColl = isCaller ? 'callerCandidates' : 'calleeCandidates';
        final cand = message['candidate'];
        if (cand is Map<String, dynamic>) {
          await _db
              .collection('callSignaling')
              .doc(roomId)
              .collection(myColl)
              .add(cand);
        }
        break;

      default:
        debugPrint('FirestoreSignaling: tipo desconocido: $type');
    }
  }

  // ─────────────────────────────────────────────────────────
  // CLOSE
  // ─────────────────────────────────────────────────────────

  Future<void> close() async {
    _connected = false;
    onConnectionChanged?.call(false);
    await _roomSub?.cancel();
    await _candidateSub?.cancel();
    _roomSub = null;
    _candidateSub = null;
  }
}
