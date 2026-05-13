import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CallDiagnosticsService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> logEvent({
    required String eventType,
    String? callSessionId,
    String? roomId,
    String? peerUserId,
    Map<String, Object?> extra = const <String, Object?>{},
  }) async {
    final me = _auth.currentUser;
    if (me == null) return;

    await _db.collection('callDiagnostics').add({
      'callSessionId': (callSessionId ?? '').trim(),
      'roomId': (roomId ?? '').trim(),
      'actorUid': me.uid,
      'peerUserId': (peerUserId ?? '').trim(),
      'eventType': eventType,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().toUtc().add(const Duration(days: 14)),
      ),
      'extra': Map<String, Object?>.from(extra),
    });
  }
}
