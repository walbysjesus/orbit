import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CallSessionService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<String> createOutgoingSession({
    required String calleeId,
  }) async {
    final me = _auth.currentUser;
    if (me == null) throw StateError('No hay sesión activa');

    final ref = _db.collection('callSessions').doc();
    await ref.set({
      'callerId': me.uid,
      'callerName': me.displayName,
      'calleeId': calleeId,
      'status': 'ringing',
      'startedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'endedAt': null,
    });
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
        .snapshots();
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> sessionStream(
      String callId) {
    return _db.collection('callSessions').doc(callId).snapshots();
  }

  static Future<void> acceptSession(String callId) async {
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
    await _db.collection('callSessions').doc(callId).update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
