import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import 'resilient_stream_helper.dart';

class OrganizationService {
  OrganizationService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<String> createOrganizationForAdmin({
    required String adminUid,
    required String organizationName,
    required String sector,
    required int seatsPurchased,
  }) async {
    final trimmedName = organizationName.trim();
    final normalizedSector = sector.trim().toLowerCase();
    if (trimmedName.isEmpty) {
      throw Exception('El nombre de la organización es obligatorio');
    }
    if (seatsPurchased < 1) {
      throw Exception('La organización debe iniciar con al menos 1 cupo');
    }

    final orgRef = _db.collection('organizations').doc();
    final memberRef =
        _db.collection('organizationUsers').doc('${orgRef.id}_$adminUid');

    await _db.runTransaction((tx) async {
      tx.set(orgRef, {
        'name': trimmedName,
        'sector': normalizedSector,
        'adminUid': adminUid,
        'seatsPurchased': seatsPurchased,
        'seatsUsed': 1,
        'status': 'active',
        'plan': 'b2b_starter',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.set(memberRef, {
        'orgId': orgRef.id,
        'uid': adminUid,
        'role': 'admin',
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    return orgRef.id;
  }

  static Future<void> joinOrganizationAsEmployee({
    required String orgId,
    required String uid,
  }) async {
    final orgRef = _db.collection('organizations').doc(orgId);
    final memberRef = _db.collection('organizationUsers').doc('${orgId}_$uid');

    await _db.runTransaction((tx) async {
      final orgSnap = await tx.get(orgRef);
      if (!orgSnap.exists) {
        throw Exception('La organización no existe');
      }

      final data = orgSnap.data()!;
      final seatsPurchased = (data['seatsPurchased'] as num?)?.toInt() ?? 0;
      final seatsUsed = (data['seatsUsed'] as num?)?.toInt() ?? 0;
      if (seatsUsed >= seatsPurchased) {
        throw Exception('No hay cupos disponibles. Solicita ampliación.');
      }

      final memberSnap = await tx.get(memberRef);
      if (!memberSnap.exists) {
        tx.set(memberRef, {
          'orgId': orgId,
          'uid': uid,
          'role': 'employee',
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.update(orgRef, {
          'seatsUsed': seatsUsed + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  static Future<void> expandSeats({
    required String orgId,
    required int additionalSeats,
    required String actorUid,
  }) async {
    if (additionalSeats <= 0) {
      throw Exception('La ampliación de cupos debe ser mayor a 0');
    }

    final orgRef = _db.collection('organizations').doc(orgId);
    final adminMemberRef =
        _db.collection('organizationUsers').doc('${orgId}_$actorUid');

    await _db.runTransaction((tx) async {
      final memberSnap = await tx.get(adminMemberRef);
      final role = memberSnap.data()?['role'] as String?;
      if (!memberSnap.exists || role != 'admin') {
        throw Exception('Solo un admin puede ampliar cupos');
      }

      final orgSnap = await tx.get(orgRef);
      if (!orgSnap.exists) {
        throw Exception('La organización no existe');
      }

      final currentSeats =
          (orgSnap.data()?['seatsPurchased'] as num?)?.toInt() ?? 0;
      tx.update(orgRef, {
        'seatsPurchased': currentSeats + additionalSeats,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> membersStream(
    String orgId, {
    void Function(ResilientStreamStatus status)? onStatus,
  }) {
    return ResilientStreamHelper.resilientStream(
      streamFactory: () => _db
          .collection('organizationUsers')
          .where('orgId', isEqualTo: orgId)
          .orderBy('createdAt', descending: false)
          .snapshots(),
      timeout: const Duration(seconds: 15),
      onStatus: onStatus,
      logTag: 'OrgMembersStream:$orgId',
    );
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> invitesStream(
    String orgId, {
    void Function(ResilientStreamStatus status)? onStatus,
  }) {
    return ResilientStreamHelper.resilientStream(
      streamFactory: () => _db
          .collection('organizationInvites')
          .where('orgId', isEqualTo: orgId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      timeout: const Duration(seconds: 15),
      onStatus: onStatus,
      logTag: 'OrgInvitesStream:$orgId',
    );
  }

  static Future<void> createInvite({
    required String orgId,
    required String adminUid,
    required String email,
    String role = 'employee',
  }) async {
    final trimmedEmail = email.trim().toLowerCase();
    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      throw Exception('Correo de invitación inválido');
    }

    final ref = _db.collection('organizationInvites').doc();
    await ref.set({
      'orgId': orgId,
      'email': trimmedEmail,
      'role': role,
      'status': 'pending',
      'createdBy': adminUid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> setMemberActive({
    required String orgId,
    required String targetUid,
    required String adminUid,
    required bool active,
  }) async {
    final adminRef =
        _db.collection('organizationUsers').doc('${orgId}_$adminUid');
    final targetRef =
        _db.collection('organizationUsers').doc('${orgId}_$targetUid');

    await _db.runTransaction((tx) async {
      final adminSnap = await tx.get(adminRef);
      final adminRole = adminSnap.data()?['role'] as String?;
      if (!adminSnap.exists || adminRole != 'admin') {
        throw Exception('Solo admin puede cambiar estado de miembros');
      }

      final targetSnap = await tx.get(targetRef);
      if (!targetSnap.exists) {
        throw Exception('Miembro no encontrado');
      }
      final targetRole = targetSnap.data()?['role'] as String?;
      if (targetRole == 'admin') {
        throw Exception('No puedes desactivar otro admin desde este panel');
      }

      tx.update(targetRef, {
        'active': active,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> recordUsageForUser({
    required String uid,
    int messagesIncrement = 0,
    int callSecondsIncrement = 0,
  }) async {
    if (messagesIncrement <= 0 && callSecondsIncrement <= 0) return;

    final userSnap = await _db.collection('users').doc(uid).get();
    final orgId = (userSnap.data()?['organizationId'] as String?)?.trim();
    if (orgId == null || orgId.isEmpty) return;

    final now = DateTime.now().toUtc();
    final dayKey =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final bucket = sha256
            .convert(utf8.encode('$orgId|$uid|$dayKey'))
            .bytes
            .first %
        16;
    final shardId = '${dayKey}_b$bucket';

    final usageRef = _db
        .collection('organizationUsage')
        .doc(orgId)
        .collection('dailyShards')
        .doc(shardId);
    final callMinutes = (callSecondsIncrement / 60).ceil();

    await usageRef.set({
      'orgId': orgId,
      'dayKey': dayKey,
      'bucket': bucket,
      'messagesSent': FieldValue.increment(messagesIncrement),
      'minutesUsed': FieldValue.increment(callMinutes),
      'usersSeen': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Legacy summary kept for compatibility but touched less often by the app.
    if (messagesIncrement >= 10 || callSecondsIncrement >= 600) {
      await _db.collection('organizationUsage').doc(orgId).set({
        'orgId': orgId,
        'lastSummaryAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }
}
