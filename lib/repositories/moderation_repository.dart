import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/core/firestore_collections.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:tarnobrzeg112/models/moderation_log.dart';
import 'package:tarnobrzeg112/models/report_model.dart';
import 'package:tarnobrzeg112/utils/text_utils.dart';
import 'package:uuid/uuid.dart';

class ModerationRepository {
  ModerationRepository(this._firestore);

  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();

  Stream<List<ReportModel>> watchReports() {
    return _firestore
        .collection(FirestoreCollections.reports)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(ReportModel.fromSnapshot).toList(),
        );
  }

  Stream<List<ModerationLog>> watchLogs() {
    return _firestore
        .collection(FirestoreCollections.moderationLogs)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(ModerationLog.fromSnapshot).toList(),
        );
  }

  Future<void> logAction({
    required AppUser actor,
    required String action,
    AppUser? target,
    String? targetUserId,
    String? targetUserLogin,
    String? targetMessageId,
    String? oldValue,
    String? newValue,
  }) {
    final id = _uuid.v4();
    final log = ModerationLog(
      id: id,
      action: action,
      performedBy: actor.uid,
      performedByLogin: actor.login,
      targetUserId: target?.uid ?? targetUserId,
      targetUserLogin: target?.login ?? targetUserLogin,
      targetMessageId: targetMessageId,
      oldValue: oldValue,
      newValue: newValue,
      createdAt: DateTime.now(),
    );
    return _firestore
        .collection(FirestoreCollections.moderationLogs)
        .doc(id)
        .set(log.toMap());
  }

  Future<void> resolveReport({
    required String reportId,
    required AppUser admin,
  }) async {
    await _firestore
        .collection(FirestoreCollections.reports)
        .doc(reportId)
        .update({
          'status': 'resolved',
          'resolvedAt': FieldValue.serverTimestamp(),
          'assignedAdminId': admin.uid,
        });
    await logAction(actor: admin, action: 'resolve_report', newValue: reportId);
  }

  Future<void> changeAccountStatus({
    required AppUser actor,
    required AppUser target,
    required AccountStatus status,
  }) async {
    await _firestore
        .collection(FirestoreCollections.users)
        .doc(target.uid)
        .update({'accountStatus': status.name});
    await logAction(
      actor: actor,
      action: 'change_account_status',
      target: target,
      oldValue: target.accountStatus.name,
      newValue: status.name,
    );
  }

  Future<void> changeRole({
    required AppUser actor,
    required AppUser target,
    required UserRole role,
  }) async {
    await _firestore
        .collection(FirestoreCollections.users)
        .doc(target.uid)
        .update({'role': role.name});
    await logAction(
      actor: actor,
      action: 'change_role',
      target: target,
      oldValue: target.role.name,
      newValue: role.name,
    );
  }

  Future<void> muteUser({
    required AppUser actor,
    required AppUser target,
    required Duration duration,
    String reason = 'Decyzja moderatora',
  }) async {
    final mutedUntil = DateTime.now().add(duration);
    await _firestore
        .collection(FirestoreCollections.users)
        .doc(target.uid)
        .update({
          'muted': true,
          'mutedUntil': Timestamp.fromDate(mutedUntil),
          'mutedReason': reason,
          'mutedBy': actor.uid,
          'blockedWrite': true,
        });
    await logAction(
      actor: actor,
      action: 'mute_user',
      target: target,
      oldValue: target.mutedUntil?.toIso8601String(),
      newValue: '${mutedUntil.toIso8601String()} | $reason',
    );
  }

  Future<void> unmuteUser({
    required AppUser actor,
    required AppUser target,
  }) async {
    await _firestore
        .collection(FirestoreCollections.users)
        .doc(target.uid)
        .update({
          'muted': false,
          'mutedUntil': null,
          'mutedReason': '',
          'mutedBy': '',
          'blockedWrite': false,
        });
    await logAction(
      actor: actor,
      action: 'unmute_user',
      target: target,
      oldValue: target.mutedReason,
      newValue: 'unmuted',
    );
  }

  Future<void> updateModeratorPermissions({
    required AppUser actor,
    required AppUser target,
    required Map<String, bool> permissions,
  }) async {
    await _firestore
        .collection(FirestoreCollections.users)
        .doc(target.uid)
        .update({'moderatorPermissions': permissions});
    await logAction(
      actor: actor,
      action: 'update_moderator_permissions',
      target: target,
      oldValue: target.moderatorPermissions.toString(),
      newValue: permissions.toString(),
    );
  }

  Future<void> updateUserServiceData({
    required AppUser actor,
    required AppUser target,
    required String voivodeship,
    required String county,
    required UnitType unitType,
    required String unitName,
  }) async {
    final unitId = TextUtils.normalizeId(unitName);
    final batch = _firestore.batch();
    final userRef = _firestore
        .collection(FirestoreCollections.users)
        .doc(target.uid);
    final unitRef = _firestore
        .collection(FirestoreCollections.units)
        .doc(unitId);
    batch.update(userRef, {
      'voivodeship': voivodeship,
      'county': county,
      'unitType': unitType.name,
      'unitName': unitName,
      'unitId': unitId,
      'publicName': '${target.nickname} ($unitName)',
    });
    if (unitId.isNotEmpty && unitType.hasOwnUnitChat) {
      batch.set(unitRef, {
        'id': unitId,
        'name': unitName,
        'type': unitType.name,
        'voivodeship': voivodeship,
        'county': county,
        'memberIds': FieldValue.arrayUnion([target.uid]),
        'active': true,
      }, SetOptions(merge: true));
    }
    await batch.commit();
    await logAction(
      actor: actor,
      action: 'change_service_data',
      target: target,
      oldValue:
          '${target.voivodeship}/${target.county}/${target.unitType.name}/${target.unitName}',
      newValue: '$voivodeship/$county/${unitType.name}/$unitName',
    );
  }
}
