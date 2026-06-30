import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'resilient_stream_helper.dart';

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
  bool _hasSeenConnectedStatus = false;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roomSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _candidateSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _eventSub;
  ResilientStreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _roomResilient;
  ResilientStreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _candidateResilient;
  ResilientStreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _eventResilient;
  final Set<String> _handledEventIds = <String>{};
  final Set<String> _handledCandidateIds = <String>{};
  final Set<String> _handledRestartRequestIds = <String>{};
  final List<Map<String, dynamic>> _pendingLocalCandidates =
      <Map<String, dynamic>>[];
  Timer? _candidateFlushTimer;
  bool _cleanupDone = false;

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
    _hasSeenConnectedStatus = false;
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

      // Rehidratar: si ya había SDP guardado (reconexión), procesarlo de inmediato.
      await _rehydrateFromSnapshot();

      // Escuchar cambios del documento de sala (SDP + presencia)
      _roomResilient =
          ResilientStreamSubscription<DocumentSnapshot<Map<String, dynamic>>>(
        streamFactory: () =>
            _db.collection('callSignaling').doc(roomId).snapshots(),
        timeout: const Duration(seconds: 15),
        logTag: 'FirestoreSignalingRoom:$roomId',
        onStatus: _handleResilientStatus,
        onError: (error, _) => _onStreamError(error),
        onData: _onRoomSnapshot,
      );
      _roomResilient!.start();

      // Escuchar candidatos ICE del otro extremo
      final remoteColl = isCaller ? 'calleeCandidates' : 'callerCandidates';
      _candidateResilient =
          ResilientStreamSubscription<QuerySnapshot<Map<String, dynamic>>>(
        streamFactory: () => _db
            .collection('callSignaling')
            .doc(roomId)
            .collection(remoteColl)
            .limit(256)
            .snapshots(),
        timeout: const Duration(seconds: 15),
        logTag: 'FirestoreSignalingCandidates:$roomId',
        onStatus: _handleResilientStatus,
        onError: (error, _) => _onStreamError(error),
        onData: _onCandidatesSnapshot,
      );
      _candidateResilient!.start();

      // Canal redundante de eventos (offer/answer) para mayor tolerancia
      // a pérdidas temporales de snapshots en enlaces inestables.
      _eventResilient =
          ResilientStreamSubscription<QuerySnapshot<Map<String, dynamic>>>(
        streamFactory: () => _db
            .collection('callSignaling')
            .doc(roomId)
            .collection('events')
            .limit(256)
            .snapshots(),
        timeout: const Duration(seconds: 15),
        logTag: 'FirestoreSignalingEvents:$roomId',
        onStatus: _handleResilientStatus,
        onError: (error, _) => _onStreamError(error),
        onData: _onEventsSnapshot,
      );
      _eventResilient!.start();
    } catch (e) {
      _connected = false;
      onConnectionChanged?.call(false);
      onError?.call('Error al conectar señalización: $e');
      rethrow;
    }
  }

  /// Lee el documento actual una vez y emite offer/answer si ya existen.
  Future<void> _rehydrateFromSnapshot() async {
    try {
      final snap = await _db.collection('callSignaling').doc(roomId).get();
      if (!snap.exists) return;
      final data = snap.data()!;

      if (isCaller) {
        if (data['calleeJoinedAt'] != null && !_peerJoinedEmitted) {
          _peerJoinedEmitted = true;
          onMessage?.call({'type': 'peer-joined'});
        }
        if (data['sdpAnswer'] != null && !_answerEmitted) {
          _answerEmitted = true;
          final sdpAnswer = data['sdpAnswer'] as Map<String, dynamic>;
          onMessage?.call({
            'type': 'answer',
            'sdp': sdpAnswer['sdp'] as String?,
          });
        }
      } else {
        if (data['sdpOffer'] != null && !_offerEmitted) {
          _offerEmitted = true;
          final sdpOffer = data['sdpOffer'] as Map<String, dynamic>;
          onMessage?.call({
            'type': 'offer',
            'sdp': sdpOffer['sdp'] as String?,
          });
        }
      }
    } catch (_) {
      // No bloquear la conexión si la rehidratación falla.
    }
  }

  Future<void> _finalizeCleanup() async {
    if (_cleanupDone) return;
    _cleanupDone = true;
    try {
      await flushPendingCandidates();
    } catch (_) {
      // Ignore and continue with room cleanup.
    }
    try {
      await cleanupRoom();
    } catch (_) {
      // Best-effort cleanup.
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
        if (_handledCandidateIds.contains(change.doc.id)) continue;
        _handledCandidateIds.add(change.doc.id);
        final d = change.doc.data();
        if (d != null) {
          final candidates = d['candidates'];
          if (candidates is List) {
            debugPrint(
                'FirestoreSignaling[$roomId]: remote ICE batch received (${change.doc.id}) size=${candidates.length}');
            for (final item in candidates) {
              if (item is Map) {
                onMessage?.call({
                  'type': 'candidate',
                  'candidate':
                      Map<String, dynamic>.from(item.cast<String, dynamic>()),
                });
              }
            }
          } else {
            debugPrint(
                'FirestoreSignaling[$roomId]: remote candidate received (${change.doc.id})');
            onMessage?.call({'type': 'candidate', 'candidate': d});
          }
        }
      }
    }
  }

  void _onEventsSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    for (final change in snap.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      final docId = change.doc.id;
      if (_handledEventIds.contains(docId)) continue;

      final data = change.doc.data();
      if (data == null) continue;

      _handledEventIds.add(docId);
      final type = data['type'] as String?;
      if (type == null) continue;

      // Evitar duplicados: solo usar eventos cuando no haya sido emitido
      // por la ruta principal del documento de sala.
      if (type == 'offer' && !isCaller && !_offerEmitted) {
        _offerEmitted = true;
        onMessage?.call({'type': 'offer', 'sdp': data['sdp'] as String?});
      } else if (type == 'answer' && isCaller && !_answerEmitted) {
        _answerEmitted = true;
        onMessage?.call({'type': 'answer', 'sdp': data['sdp'] as String?});
      } else if (type == 'restartIce') {
        final requestId = (data['requestId'] as String?)?.trim();
        final restartId =
            (requestId == null || requestId.isEmpty) ? docId : requestId;
        if (_handledRestartRequestIds.contains(restartId)) {
          debugPrint(
              'FirestoreSignaling[$roomId]: duplicate restartIce ignored id=$restartId');
          continue;
        }
        _handledRestartRequestIds.add(restartId);
        final from = (data['from'] as String?)?.trim();
        final reason = (data['reason'] as String?)?.trim();
        debugPrint(
            'FirestoreSignaling[$roomId]: restartIce event received id=$restartId from=$from reason=$reason');
        onMessage?.call({
          'type': 'restartIce',
          'requestId': restartId,
          if (from != null && from.isNotEmpty) 'from': from,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        });
      }
    }
  }

  void _onStreamError(Object error) {
    debugPrint('FirestoreSignaling error: $error');
    onError?.call('Error en señalización Firestore');
  }

  void _handleResilientStatus(ResilientStreamStatus status) {
    if (status == ResilientStreamStatus.connected) {
      _hasSeenConnectedStatus = true;
      return;
    }
    if (!_hasSeenConnectedStatus) {
      return;
    }
    if (status == ResilientStreamStatus.reconnecting) {
      onError?.call('Reconectando...');
    } else if (status == ResilientStreamStatus.timeout ||
        status == ResilientStreamStatus.offline) {
      onError?.call('Sin conexión');
    }
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
        debugPrint('FirestoreSignaling[$roomId]: send offer');
        await _db.collection('callSignaling').doc(roomId).set(
          {
            'sdpOffer': {'type': 'offer', 'sdp': message['sdp']},
          },
          SetOptions(merge: true),
        );
        await _db
            .collection('callSignaling')
            .doc(roomId)
            .collection('events')
            .add({
          'type': 'offer',
          'sdp': message['sdp'],
          'createdAt': FieldValue.serverTimestamp(),
        });
        break;

      case 'answer':
        debugPrint('FirestoreSignaling[$roomId]: send answer');
        await _db.collection('callSignaling').doc(roomId).set(
          {
            'sdpAnswer': {'type': 'answer', 'sdp': message['sdp']},
          },
          SetOptions(merge: true),
        );
        await _db
            .collection('callSignaling')
            .doc(roomId)
            .collection('events')
            .add({
          'type': 'answer',
          'sdp': message['sdp'],
          'createdAt': FieldValue.serverTimestamp(),
        });
        break;

      case 'candidate':
        final cand = message['candidate'];
        if (cand is Map<String, dynamic>) {
          _pendingLocalCandidates.add({
            ...cand,
            // Firestore no admite sentinels (serverTimestamp) dentro de arrays.
            'createdAt': Timestamp.now(),
          });
          _candidateFlushTimer?.cancel();
          _candidateFlushTimer = Timer(const Duration(milliseconds: 250), () {
            unawaited(flushPendingCandidates());
          });
        }
        break;

      case 'restartIce':
        final requestId = (message['requestId'] as String?)
                    ?.trim()
                    .isNotEmpty ==
                true
            ? (message['requestId'] as String).trim()
            : '${isCaller ? 'caller' : 'callee'}_${DateTime.now().microsecondsSinceEpoch}';
        final from = (message['from'] as String?)?.trim();
        final reason = (message['reason'] as String?)?.trim();
        debugPrint(
            'FirestoreSignaling[$roomId]: send restartIce id=$requestId from=$from reason=$reason');
        await _db
            .collection('callSignaling')
            .doc(roomId)
            .collection('events')
            .add({
          'type': 'restartIce',
          'requestId': requestId,
          if (from != null && from.isNotEmpty) 'from': from,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
          'createdAt': FieldValue.serverTimestamp(),
        });
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
    _candidateFlushTimer?.cancel();
    await flushPendingCandidates();
    await _roomResilient?.cancel();
    await _candidateResilient?.cancel();
    await _eventResilient?.cancel();
    _roomResilient = null;
    _candidateResilient = null;
    _eventResilient = null;
    await _roomSub?.cancel();
    await _candidateSub?.cancel();
    await _eventSub?.cancel();
    _roomSub = null;
    _candidateSub = null;
    _eventSub = null;
    _handledEventIds.clear();
    _handledCandidateIds.clear();
    _handledRestartRequestIds.clear();
    await _finalizeCleanup();
  }

  Future<void> flushPendingCandidates() async {
    if (_pendingLocalCandidates.isEmpty) return;

    final myColl = isCaller ? 'callerCandidates' : 'calleeCandidates';
    final payload = List<Map<String, dynamic>>.from(_pendingLocalCandidates);
    _pendingLocalCandidates.clear();
    await _db
        .collection('callSignaling')
        .doc(roomId)
        .collection(myColl)
        .doc()
        .set({
      'kind': 'candidateBatch',
      'candidates': payload,
      'batchCount': payload.length,
      'createdAt': FieldValue.serverTimestamp(),
    });
    debugPrint(
        'FirestoreSignaling[$roomId]: flushed ICE candidate batch to $myColl size=${payload.length}');
  }

  Future<void> cleanupRoom() async {
    final roomRef = _db.collection('callSignaling').doc(roomId);
    const collections = <String>[
      'callerCandidates',
      'calleeCandidates',
      'events'
    ];

    for (final collectionName in collections) {
      final snap = await roomRef.collection(collectionName).get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    }

    await roomRef.delete().catchError((_) {});
    debugPrint('FirestoreSignaling[$roomId]: room cleanup completed');
  }
}
