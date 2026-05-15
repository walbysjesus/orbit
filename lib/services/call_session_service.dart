import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';
import 'organization_service.dart';
import 'remote_notification_service.dart';

class CallSessionService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<String> createOutgoingSession({
    required String calleeId,
    bool audioOnly = false,
  }) async {
    final me = _auth.currentUser;
    if (me == null) throw StateError('No hay sesión activa');
    if (calleeId == me.uid) {
      throw ArgumentError('No puedes llamarte a ti mismo');
    }
    await AuthService.ensureCommunicationAccess();

    final ref = _db.collection('callSessions').doc();
    await ref.set({
      'callerId': me.uid,
      'callerName': me.displayName ?? '',
      'calleeId': calleeId,
      'callType': audioOnly ? 'voice' : 'video',
      'pushMode': 'direct',
      'status': 'ringing',
      'startedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      // El receptor debe contestar antes de este timestamp o se cancela.
      'ringingExpiresAt': Timestamp.fromDate(
        DateTime.now().toUtc().add(const Duration(seconds: 30)),
      ),
    });

    await RemoteNotificationService.notifyUser(
      targetUserId: calleeId,
      type: 'incoming_call',
      title: audioOnly ? 'Llamada de voz entrante' : 'Videollamada entrante',
      body: (me.displayName ?? '').trim().isEmpty
          ? 'Tienes una llamada entrante'
          : '${me.displayName} te está llamando',
      data: {
        'callSessionId': ref.id,
        'callerId': me.uid,
        'callType': audioOnly ? 'voice' : 'video',
      },
    );

    return ref.id;
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> incomingRingingStream() {
    final me = _auth.currentUser;
    if (me == null) {
      return const Stream.empty();
    }

    return _db
        .collection('callSessions')
        .where('calleeId', isEqualTo: me.uid)
        .where('status', isEqualTo: 'ringing')
        .orderBy('updatedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
      // Filtrar sesiones cuyo ringing ya expiró (evita llamadas fantasma).
      final now = Timestamp.now();
      final validDocs = snap.docs.where((doc) {
        final expires = doc.data()['ringingExpiresAt'] as Timestamp?;
        if (expires == null) {
          return true; // sesión sin expiración: compatible hacia atrás
        }
        return expires.compareTo(now) > 0;
      }).toList();

      // Limpiar sesiones expiradas en segundo plano.
      for (final doc in snap.docs) {
        final expires = doc.data()['ringingExpiresAt'] as Timestamp?;
        if (expires != null && expires.compareTo(now) <= 0) {
          doc.reference.update({
            'status': 'missed',
            'endedAt': FieldValue.serverTimestamp(),
          }).catchError((_) {});
        }
      }

      return validDocs.isEmpty ? snap : snap;
    });
  }

  /// Cancela automáticamente sesiones ringing expiradas iniciadas por el caller.
  static Future<void> cancelExpiredRinging(String callId) async {
    try {
      final snap = await _db.collection('callSessions').doc(callId).get();
      if (!snap.exists) return;
      final data = snap.data()!;
      if (data['status'] != 'ringing') return;
      final expires = data['ringingExpiresAt'] as Timestamp?;
      if (expires != null && expires.compareTo(Timestamp.now()) <= 0) {
        await _db.collection('callSessions').doc(callId).update({
          'status': 'missed',
          'endedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> sessionStream(
      String callId) {
    return _db.collection('callSessions').doc(callId).snapshots();
  }

  static Future<void> acceptSession(String callId) async {
    await AuthService.ensureCommunicationAccess();
    await _db.collection('callSessions').doc(callId).update({
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> rejectSession(String callId) async {
    await _db.collection('callSessions').doc(callId).update({
      'status': 'rejected',
      'endedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> endSession(String callId) async {
    final me = _auth.currentUser;
    if (me == null) throw StateError('No hay sesión activa');
    await AuthService.ensureCommunicationAccess();

    final callSnap = await _db.collection('callSessions').doc(callId).get();
    final callData = callSnap.data() ?? <String, dynamic>{};
    final startedAt = (callData['startedAt'] as Timestamp?)?.toDate();
    final endedAt = DateTime.now();
    final durationSeconds = startedAt == null
        ? 0
        : endedAt.difference(startedAt).inSeconds.clamp(0, 86400);

    await _db.collection('callSessions').doc(callId).update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await OrganizationService.recordUsageForUser(
      uid: me.uid,
      callSecondsIncrement: durationSeconds,
    );
  }
}
