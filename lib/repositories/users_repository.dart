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
          debugPrint(
            'AUTH DEBUG provider bootstrap admin write failed UID=$authUid '
            'error=$error',
          );
        }),
      );
      yield _startAdminFallback(authUid);
    }
    try {
      await for (final uidDoc in userRef(authUid).snapshots()) {
        debugPrint('AUTH DEBUG current UID=$authUid');
        debugPrint(
          'AUTH DEBUG fetched document=users/$authUid '
          'exists=${uidDoc.exists} data=${uidDoc.data()}',
        );
        if (!uidDoc.exists) {
          debugPrint('AUTH DEBUG accountStatus=missing');
          if (isStartAdmin) {
            yield _startAdminFallback(authUid);
          } else {
            yield null;
          }
          continue;
        }
        final appUser = AppUser.fromSnapshot(uidDoc);
        debugPrint(
          'AUTH DEBUG accountStatus=${appUser.accountStatus.name} '
          'role=${appUser.role.name}',
        );
        if (isStartAdmin) {
          yield _startAdminFallback(authUid);
          continue;
        }
        yield appUser;
      }
    } on FirebaseException catch (error) {
      debugPrint(
        'AUTH DEBUG profile stream failed UID=$authUid '
        'FirebaseException.code=${error.code} message=${error.message}',
      );
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

  Future<void> _writeStartAdminProfile(String authUid) {
    final appUser = _startAdminFallback(authUid);
    return userRef(authUid).set({
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
  }

  Stream<List<AppUser>> watchUsers({AccountStatus? status, int limit = 50}) {
    Query<Map<String, dynamic>> query = _firestore.collection(
      FirestoreCollections.users,
    );
    if (status != null) {
      query = query.where('accountStatus', isEqualTo: status.name);
    }
    return query.limit(limit).snapshots().map((snapshot) {
      final users = snapshot.docs.map(AppUser.fromSnapshot);
      final byLogin = <String, AppUser>{};
      for (final user in users) {
        final key = user.login.isEmpty ? user.uid : user.login;
        byLogin[key] = user;
      }
      return byLogin.values.toList()
        ..sort((a, b) => b.joinedAt.compareTo(a.joinedAt));
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
      final users = snapshot.docs.map(AppUser.fromSnapshot);
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
          return snapshot.docs.map(AppUser.fromSnapshot).toList()..sort((a, b) {
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
            final type = UnitType.fromWire(doc.data()['unitType'] as String?);
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
    XFile? avatar,
  }) async {
    String? avatarUrl = user.avatarUrl;
    if (avatar != null) {
      avatarUrl = await _storageService.uploadAvatar(
        uid: user.uid,
        file: avatar,
      );
    }
    await userRef(user.uid).update({
      'nickname': nickname.trim(),
      'phoneNumber': phoneNumber.trim(),
      'description': description.trim(),
      'avatarUrl': avatarUrl,
      'publicName': user.unitName.trim().isEmpty
          ? nickname.trim()
          : '$nickname (${user.unitName})',
    });
  }

  Future<void> updatePresence(String uid, PresenceStatus status) {
    return userRef(uid).update({
      'presenceStatus': status.name,
      'lastSeenAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveFcmToken(String uid, String token) {
    return userRef(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
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
    batch.update(userRef(user.uid), {
      'unitType': unitType.name,
      'unitName': unitName.trim(),
      'unitId': unitId,
      'publicName': unitName.trim().isEmpty
          ? user.nickname
          : '${user.nickname} (${unitName.trim()})',
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
