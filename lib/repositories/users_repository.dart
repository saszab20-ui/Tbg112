import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tarnobrzeg112/core/app_constants.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/core/firestore_collections.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:tarnobrzeg112/services/storage_service.dart';
import 'package:tarnobrzeg112/utils/text_utils.dart';

class UsersRepository {
  UsersRepository(this._firestore, this._storageService);

  final FirebaseFirestore _firestore;
  final StorageService _storageService;
  final Map<String, _PresenceWrite> _lastPresenceWrites = {};

  DocumentReference<Map<String, dynamic>> userRef(String uid) {
    return _firestore.collection(FirestoreCollections.users).doc(uid);
  }

  Stream<AppUser?> watchUser(String uid) {
    return userRef(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AppUser.fromSnapshot(doc);
    });
  }

  Stream<AppUser?> watchAuthenticatedUser({
    required String authUid,
    required String? authEmail,
  }) async* {
    final isStartAdmin =
        authEmail?.toLowerCase() ==
        '${AppConstants.superAdminLogin}@${AppConstants.technicalEmailDomain}';
    if (isStartAdmin) {
      unawaited(
        _writeStartAdminProfile(authUid).catchError((Object error) {
          if (kDebugMode) {
            debugPrint(
              'AUTH DEBUG provider bootstrap admin write failed UID=$authUid '
              'error=$error',
            );
          }
        }),
      );
    }
    try {
      await for (final uidDoc in userRef(authUid).snapshots()) {
        if (kDebugMode) {
          debugPrint(
            'AUTH DEBUG profile snapshot uid=$authUid exists=${uidDoc.exists}',
          );
        }
        if (!uidDoc.exists) {
          if (kDebugMode) debugPrint('AUTH DEBUG accountStatus=missing');
          if (isStartAdmin) {
            yield _startAdminFallback(authUid);
          } else {
            yield null;
          }
          continue;
        }
        final appUser = AppUser.fromSnapshot(uidDoc);
        if (kDebugMode) {
          debugPrint(
            'AUTH DEBUG accountStatus=${appUser.accountStatus.name} '
            'role=${appUser.role.name}',
          );
        }
        if (isStartAdmin) {
          yield appUser.copyWith(
            uid: authUid,
            login: AppConstants.superAdminLogin,
            email:
                '${AppConstants.superAdminLogin}@${AppConstants.technicalEmailDomain}',
            role: UserRole.admin,
            accountStatus: AccountStatus.active,
            blockedWrite: false,
          );
          continue;
        }
        yield appUser;
      }
    } on FirebaseException catch (error) {
      if (kDebugMode) {
        debugPrint(
          'AUTH DEBUG profile stream failed UID=$authUid '
          'FirebaseException.code=${error.code} message=${error.message}',
        );
      }
      if (isStartAdmin) {
        yield _startAdminFallback(authUid);
      } else {
        rethrow;
      }
    }
  }

  AppUser _startAdminFallback(String authUid) {
    const login = AppConstants.superAdminLogin;
    const unitName = 'OSP Gorzyce';
    return AppUser(
      uid: authUid,
      login: login,
      email: '$login@${AppConstants.technicalEmailDomain}',
      firstName: 'Sławomir',
      lastName: 'Badura',
      nickname: 'Sławomir Badura',
      phoneNumber: '',
      unitType: UnitType.osp,
      unitId: TextUtils.normalizeId(unitName),
      unitName: unitName,
      voivodeship: AppConstants.defaultVoivodeship,
      county: AppConstants.defaultCounty,
      role: UserRole.admin,
      accountStatus: AccountStatus.active,
      presenceStatus: PresenceStatus.offline,
      joinedAt: DateTime.now(),
      lastSeenAt: DateTime.now(),
      blockedWrite: false,
    );
  }

  Future<void> _writeStartAdminProfile(String authUid) async {
    final appUser = _startAdminFallback(authUid);
    final ref = userRef(authUid);
    final snapshot = await ref.get();
    if (!snapshot.exists) {
      await ref.set({
        ...appUser.toMap(),
        'uid': authUid,
        'login': AppConstants.superAdminLogin,
        'authEmail':
            '${AppConstants.superAdminLogin}@${AppConstants.technicalEmailDomain}',
        'accountStatus': AccountStatus.active.name,
        'role': UserRole.admin.name,
        'canWrite': true,
        'displayName': 'Sławomir Badura',
        'serviceType': 'OSP',
        'unitName': 'OSP Gorzyce',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    final data = snapshot.data() ?? {};
    final alreadyValid =
        data['uid'] == authUid &&
        data['login'] == AppConstants.superAdminLogin &&
        data['authEmail'] ==
            '${AppConstants.superAdminLogin}@${AppConstants.technicalEmailDomain}' &&
        data['accountStatus'] == AccountStatus.active.name &&
        data['role'] == UserRole.admin.name &&
        data['canWrite'] == true &&
        data['blockedWrite'] == false;
    if (alreadyValid) return;

    await ref.set({
      'uid': authUid,
      'login': AppConstants.superAdminLogin,
      'authEmail':
          '${AppConstants.superAdminLogin}@${AppConstants.technicalEmailDomain}',
      'accountStatus': AccountStatus.active.name,
      'role': UserRole.admin.name,
      'canWrite': true,
      'blockedWrite': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<AppUser>> watchUsers({AccountStatus? status, int limit = 50}) {
    Query<Map<String, dynamic>> query = _firestore.collection(
      FirestoreCollections.users,
    );
    if (status != null) {
      query = query.where('accountStatus', isEqualTo: status.name);
    }
    return query.limit(limit).snapshots().map((snapshot) {
      final users = snapshot.docs
          .map(AppUser.fromSnapshot)
          .where((user) => user.accountStatus != AccountStatus.deleted);
      final byLogin = <String, AppUser>{};
      for (final user in users) {
        final key = user.login.isEmpty ? user.uid : user.login;
        byLogin[key] = user;
      }
      return byLogin.values.toList()
        ..sort((a, b) => b.joinedAt.compareTo(a.joinedAt));
    });
  }

  Stream<List<AppUser>> watchPendingUsers({int limit = 500}) {
    return _firestore
        .collection(FirestoreCollections.users)
        .where('accountStatus', isEqualTo: AccountStatus.pending.name)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final users =
              snapshot.docs
                  .map(AppUser.fromSnapshot)
                  .where((user) => user.accountStatus != AccountStatus.deleted)
                  .toList()
                ..sort((a, b) => b.joinedAt.compareTo(a.joinedAt));
          return users;
        });
  }

  Stream<List<AppUser>> watchActiveUsers({String? unitId, int limit = 80}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(FirestoreCollections.users)
        .where('accountStatus', isEqualTo: AccountStatus.active.name);
    if (unitId != null) {
      query = query.where('unitId', isEqualTo: unitId);
    }
    return query.limit(limit).snapshots().map((snapshot) {
      final users = snapshot.docs
          .map(AppUser.fromSnapshot)
          .where((user) => user.accountStatus != AccountStatus.deleted);
      final byLogin = <String, AppUser>{};
      for (final user in users) {
        final key = user.login.isEmpty ? user.uid : user.login;
        byLogin[key] = user;
      }
      return byLogin.values.toList()..sort((a, b) {
        final aDate = a.lastSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.lastSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    });
  }

  Stream<List<AppUser>> watchMutedUsers({int limit = 80}) {
    return _firestore
        .collection(FirestoreCollections.users)
        .where('muted', isEqualTo: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(AppUser.fromSnapshot)
              .where((user) => user.accountStatus != AccountStatus.deleted)
              .toList()
            ..sort((a, b) {
              final aDate =
                  a.mutedUntil ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bDate =
                  b.mutedUntil ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bDate.compareTo(aDate);
            });
        });
  }

  Stream<List<String>> watchActiveUnitNames() {
    return _firestore
        .collection(FirestoreCollections.users)
        .where('accountStatus', isEqualTo: AccountStatus.active.name)
        .limit(1000)
        .snapshots()
        .map((snapshot) {
          final names = <String>{};
          for (final doc in snapshot.docs) {
            final name = (doc.data()['unitName'] as String?)?.trim() ?? '';
            final type = UnitType.fromWire(
              (doc.data()['serviceType'] as String?) ??
                  (doc.data()['unitType'] as String?),
            );
            if (name.isNotEmpty && type.hasOwnUnitChat) names.add(name);
          }
          return names.toList()..sort();
        });
  }

  Future<void> updateEditableProfile({
    required AppUser user,
    required String nickname,
    required String phoneNumber,
    required String description,
    String? firstName,
    String? lastName,
    XFile? avatar,
  }) async {
    String? avatarUrl = user.avatarUrl;
    if (avatar != null) {
      avatarUrl = await _storageService.uploadAvatar(
        uid: user.uid,
        file: avatar,
      );
    }
    final cleanNickname = nickname.trim();
    final cleanFirstName = firstName?.trim() ?? user.firstName.trim();
    final cleanLastName = lastName?.trim() ?? user.lastName.trim();
    final displayBase = cleanNickname.isNotEmpty
        ? cleanNickname
        : cleanFirstName.isNotEmpty
        ? cleanFirstName.split(RegExp(r'\s+')).first
        : user.login;
    final publicName = user.unitName.trim().isEmpty
        ? displayBase
        : '$displayBase (${user.unitName})';
    final update = <String, Object?>{
      'nickname': nickname.trim(),
      'phoneNumber': phoneNumber.trim(),
      'description': description.trim(),
      'avatarUrl': avatarUrl,
      'publicName': publicName,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!user.hasFullName &&
        cleanFirstName.isNotEmpty &&
        cleanLastName.isNotEmpty) {
      update['firstName'] = cleanFirstName;
      update['lastName'] = cleanLastName;
      update['fullName'] = '$cleanFirstName $cleanLastName';
      update['displayName'] = cleanNickname.isNotEmpty
          ? cleanNickname
          : '$cleanFirstName $cleanLastName';
    }
    await userRef(user.uid).update(update);
  }

  Future<void> updatePresence(
    String uid,
    PresenceStatus status, {
    bool manual = false,
  }) async {
    final now = DateTime.now();
    final previous = _lastPresenceWrites[uid];

    // If this is an automatic heartbeat and not a manual change
    if (!manual) {
      // Debounce automatic updates
      if (previous != null &&
          previous.status == status &&
          now.difference(previous.at) < const Duration(seconds: 45)) {
        return;
      }

      final doc = await userRef(uid).get();
      final isManualStatus = doc.data()?['isManualStatus'] == true;

      // Don't auto-override manual override statuses with heartbeats
      if (isManualStatus) {
        return;
      }
    }

    _lastPresenceWrites[uid] = _PresenceWrite(status: status, at: now);
    return userRef(uid).update({
      'presenceStatus': status.name,
      'isManualStatus': manual,
      'lastSeenAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setCustomStatus(String uid, String statusText) {
    return userRef(uid).update({
      'presenceStatus': PresenceStatus.manual.name,
      'isManualStatus': true,
      'customStatus': statusText.trim(),
      'lastSeenAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveFcmToken(String uid, String token) {
    return userRef(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  Future<void> completeFirstLoginTutorial(String uid) {
    return userRef(uid).set({
      'firstLoginTutorialCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setAccountStatus(String uid, AccountStatus status) {
    return userRef(uid).update({'accountStatus': status.name});
  }

  Future<void> setRole(String uid, UserRole role) {
    return userRef(uid).update({'role': role.name});
  }

  Future<void> setMute(String uid, Duration duration) {
    return userRef(
      uid,
    ).update({'mutedUntil': Timestamp.fromDate(DateTime.now().add(duration))});
  }

  Future<void> setBlockedWrite(String uid, bool blocked) {
    return userRef(uid).update({'blockedWrite': blocked});
  }

  Future<void> updateUnit({
    required AppUser user,
    required UnitType unitType,
    required String unitName,
  }) async {
    final unitId = TextUtils.normalizeId(unitName);
    final batch = _firestore.batch();
    final displayBase = user.preferredChatName;
    batch.update(userRef(user.uid), {
      'unitType': unitType.name,
      'unitName': unitName.trim(),
      'unitId': unitId,
      'publicName': unitName.trim().isEmpty
          ? displayBase
          : '$displayBase (${unitName.trim()})',
    });
    batch.set(
      _firestore.collection(FirestoreCollections.units).doc(unitId),
      {
        'id': unitId,
        'name': unitName.trim(),
        'type': unitType.name,
        'memberIds': FieldValue.arrayUnion([user.uid]),
        'active': true,
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }
}

class _PresenceWrite {
  const _PresenceWrite({required this.status, required this.at});

  final PresenceStatus status;
  final DateTime at;
}
