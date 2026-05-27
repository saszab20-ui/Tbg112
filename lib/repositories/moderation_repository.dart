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
    final batch = _firestore.batch();
    final userRef = _firestore
        .collection(FirestoreCollections.users)
        .doc(target.uid);
    final canWrite = status == AccountStatus.active;
    batch.update(userRef, {
      'accountStatus': status.name,
      'canWrite': canWrite,
      'blockedWrite': !canWrite,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (status == AccountStatus.active &&
        target.unitType.hasOwnUnitChat &&
        target.unitName.trim().isNotEmpty) {
      final unitId = target.unitId.trim().isNotEmpty
          ? target.unitId
          : TextUtils.normalizeId(target.unitName);
      batch.set(
        _firestore.collection(FirestoreCollections.units).doc(unitId),
        {
          'id': unitId,
          'name': target.unitName.trim(),
          'type': target.unitType.name,
          'serviceType': target.unitType.badgeLabel,
          'voivodeship': target.voivodeship,
          'county': target.county,
          'memberIds': FieldValue.arrayUnion([target.uid]),
          'active': true,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
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
    final update = <String, Object?>{
      'role': role.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (role == UserRole.moderator && target.role != UserRole.moderator) {
      update['moderatorPermissions'] = <String, bool>{};
    }
    if (role == UserRole.user) {
      update['moderatorPermissions'] = <String, bool>{};
    }
    await _firestore
        .collection(FirestoreCollections.users)
        .doc(target.uid)
        .update(update);
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

  Future<void> archiveUser({
    required AppUser actor,
    required AppUser target,
  }) async {
    final chatSnapshots = await _firestore
        .collection(FirestoreCollections.chats)
        .where('participants', arrayContains: target.uid)
        .limit(500)
        .get();
    final unitSnapshots = await _firestore
        .collection(FirestoreCollections.units)
        .where('memberIds', arrayContains: target.uid)
        .limit(100)
        .get();

    final batch = _firestore.batch();
    final userRef = _firestore
        .collection(FirestoreCollections.users)
        .doc(target.uid);
    batch.update(userRef, {
      'accountStatus': AccountStatus.deleted.name,
      'deleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': actor.uid,
      'canWrite': false,
      'blockedWrite': true,
      'muted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    for (final chat in chatSnapshots.docs) {
      batch.set(chat.reference, {
        'participants': FieldValue.arrayRemove([target.uid]),
        'participantIds': FieldValue.arrayRemove([target.uid]),
        'participantLogins': FieldValue.arrayRemove([target.login]),
        'participantNames': FieldValue.arrayRemove([target.publicName]),
        'participantNameMap.${target.uid}': FieldValue.delete(),
        'unreadCount.${target.uid}': FieldValue.delete(),
        'typing.${target.uid}': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    for (final unit in unitSnapshots.docs) {
      batch.set(unit.reference, {
        'memberIds': FieldValue.arrayRemove([target.uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
    await logAction(
      actor: actor,
      action: 'archive_user',
      target: target,
      oldValue: target.accountStatus.name,
      newValue: AccountStatus.deleted.name,
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

  Future<void> updateUserFullName({
    required AppUser actor,
    required AppUser target,
    required String firstName,
    required String lastName,
  }) async {
    final cleanFirstName = firstName.trim();
    final cleanLastName = lastName.trim();
    final fullName = '$cleanFirstName $cleanLastName'.trim();
    await _firestore
        .collection(FirestoreCollections.users)
        .doc(target.uid)
        .update({
          'firstName': cleanFirstName,
          'lastName': cleanLastName,
          'fullName': fullName,
          'displayName': target.nickname.trim().isEmpty
              ? fullName
              : target.nickname.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
    await logAction(
      actor: actor,
      action: 'change_user_full_name',
      target: target,
      oldValue: target.fullName,
      newValue: fullName,
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
    final oldUnitId = target.unitId.trim().isEmpty
        ? TextUtils.normalizeId(target.unitName)
        : target.unitId;
    if (oldUnitId.isNotEmpty && oldUnitId != unitId) {
      batch.set(
        _firestore.collection(FirestoreCollections.units).doc(oldUnitId),
        {
          'memberIds': FieldValue.arrayRemove([target.uid]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    final cleanUnitName = unitName.trim();
    final displayBase = target.preferredChatName;
    final publicName =
        cleanUnitName.isEmpty &&
            (unitType == UnitType.media || unitType == UnitType.informator)
        ? '$displayBase (${unitType.label})'
        : cleanUnitName.isEmpty
        ? displayBase
        : '$displayBase ($cleanUnitName)';
    batch.update(userRef, {
      'voivodeship': voivodeship,
      'county': county,
      'unitType': unitType.name,
      'serviceType': unitType.badgeLabel,
      'unitName': cleanUnitName,
      'unitId': unitId,
      'publicName': publicName,
      'displayName': target.displayName,
      'updatedAt': FieldValue.serverTimestamp(),
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
