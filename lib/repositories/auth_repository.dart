import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tarnobrzeg112/core/app_constants.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/core/firestore_collections.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:tarnobrzeg112/services/storage_service.dart';
import 'package:tarnobrzeg112/utils/text_utils.dart';

class RegisterData {
  const RegisterData({
    required this.firstName,
    required this.lastName,
    required this.nickname,
    required this.login,
    required this.password,
    required this.phoneNumber,
    required this.unitType,
    required this.unitName,
    required this.voivodeship,
    required this.county,
    required this.inviteCode,
    this.adminNotes = '',
    this.avatar,
  });

  final String firstName;
  final String lastName;
  final String nickname;
  final String login;
  final String password;
  final String phoneNumber;
  final UnitType unitType;
  final String unitName;
  final String voivodeship;
  final String county;
  final String inviteCode;
  final String adminNotes;
  final XFile? avatar;
}

class AuthRepository {
  AuthRepository(this._auth, this._firestore, this._storageService);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final StorageService _storageService;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<AppUser> signIn({
    required String login,
    required String password,
  }) async {
    final normalizedLogin = TextUtils.normalizeLogin(login);
    final authEmail = technicalEmailForLogin(normalizedLogin);
    try {
      debugPrint('AUTH DEBUG entered login=$normalizedLogin');
      debugPrint('AUTH DEBUG generated email=$authEmail');
      debugPrint(
        'Firebase signIn start login=$normalizedLogin authEmail=$authEmail',
      );
      final credential = await _auth.signInWithEmailAndPassword(
        email: authEmail,
        password: password,
      );
      final firebaseUser = credential.user;
      debugPrint('AUTH DEBUG Firebase UID=${firebaseUser?.uid ?? '-'}');
      if (firebaseUser == null) {
        throw StateError(
          'Logowanie przerwane: Firebase Auth nie zwrócił UID. '
          'authEmail=$authEmail FirebaseAuthException.code=-',
        );
      }
      if (isSuperAdminLogin(normalizedLogin)) {
        final appUser = await _bootstrapStartAdminProfile(
          firebaseUser: firebaseUser,
          authEmail: authEmail,
        );
        _debugAuthProfile(
          uid: firebaseUser.uid,
          login: appUser.login,
          authEmail: authEmail,
          role: appUser.role,
          accountStatus: appUser.accountStatus,
        );
        return appUser;
      }
      final appUser = await _loadProfileAfterAuth(firebaseUser: firebaseUser);
      if (appUser == null) {
        throw StateError(
          'Brak profilu użytkownika. Skontaktuj się z administratorem. '
          'authEmail=$authEmail Firebase UID=${firebaseUser.uid} '
          'accountStatus=brak role=brak FirebaseAuthException.code=-',
        );
      }
      _debugAuthProfile(
        uid: firebaseUser.uid,
        login: appUser.login,
        authEmail: firebaseUser.email ?? authEmail,
        role: appUser.role,
        accountStatus: appUser.accountStatus,
      );
      return appUser;
    } on FirebaseAuthException catch (error) {
      _debugFirebaseAuthException('Firebase signIn failed', error);
      if ((error.code == 'user-not-found' ||
              error.code == 'invalid-credential') &&
          isSuperAdminLogin(normalizedLogin)) {
        try {
          return await _createBootstrapAdminAccount(
            login: normalizedLogin,
            password: password,
          );
        } on FirebaseAuthException catch (bootstrapError) {
          if (bootstrapError.code == 'email-already-in-use') {
            throw error;
          }
          rethrow;
        }
      }
      rethrow;
    } on Object catch (error, stackTrace) {
      debugPrint('Firebase signIn unexpected error: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<AppUser> _bootstrapStartAdminProfile({
    required User firebaseUser,
    required String authEmail,
  }) async {
    const login = AppConstants.superAdminLogin;
    const unitName = 'OSP Gorzyce';
    final appUser = AppUser(
      uid: firebaseUser.uid,
      login: login,
      email: authEmail,
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
    final adminProfile = {
      ...appUser.toMap(),
      'uid': firebaseUser.uid,
      'login': login,
      'authEmail': authEmail,
      'accountStatus': AccountStatus.active.name,
      'role': UserRole.admin.name,
      'canWrite': true,
      'displayName': 'Sławomir Badura',
      'serviceType': 'OSP',
      'unitName': unitName,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (AppConstants.devAdminMode) {
      unawaited(
        _firestore
            .collection(FirestoreCollections.users)
            .doc(firebaseUser.uid)
            .set(adminProfile, SetOptions(merge: true))
            .then(
              (_) => debugPrint(
                'AUTH DEBUG DEV_ADMIN_MODE wrote users/${firebaseUser.uid}',
              ),
            )
            .catchError((Object error) {
              debugPrint(
                'AUTH DEBUG DEV_ADMIN_MODE Firestore write skipped: $error',
              );
            }),
      );
      return appUser;
    }
    try {
      await _firestore
          .collection(FirestoreCollections.users)
          .doc(firebaseUser.uid)
          .set(adminProfile, SetOptions(merge: true));
      debugPrint(
        'AUTH DEBUG bootstrap admin profile written users/${firebaseUser.uid} '
        'accountStatus=active role=admin',
      );
      return appUser;
    } on FirebaseException catch (error) {
      debugPrint(
        'AUTH DEBUG bootstrap admin write failed code=${error.code} '
        'message=${error.message}',
      );
      debugPrint(
        'AUTH DEBUG bootstrap admin continues locally authEmail=$authEmail '
        'Firebase UID=${firebaseUser.uid} accountStatus=active role=admin '
        'FirebaseException.code=${error.code}',
      );
      return appUser;
    }
  }

  Future<AppUser> register(RegisterData data) async {
    final normalizedLogin = TextUtils.normalizeLogin(data.login);
    if (normalizedLogin.length < 3) {
      throw StateError('Login musi mieć minimum 3 znaki.');
    }

    final technicalEmail = technicalEmailForLogin(normalizedLogin);
    User? createdUser;
    var createdAuthUser = false;
    AppUser? registeredUser;
    try {
      late final UserCredential credential;
      try {
        credential = await _auth.createUserWithEmailAndPassword(
          email: technicalEmail,
          password: data.password,
        );
        createdAuthUser = true;
      } on FirebaseAuthException catch (error) {
        if (error.code != 'email-already-in-use' ||
            !skipsInviteCode(normalizedLogin)) {
          rethrow;
        }
        credential = await _auth.signInWithEmailAndPassword(
          email: technicalEmail,
          password: data.password,
        );
      }
      createdUser = credential.user;
      if (createdUser == null) {
        throw StateError('Nie udało się utworzyć konta.');
      }

      String? avatarUrl;
      if (data.avatar != null) {
        avatarUrl = await _storageService.uploadAvatar(
          uid: createdUser.uid,
          file: data.avatar!,
        );
      }

      await _firestore.runTransaction((transaction) async {
        final superAdminRef = _firestore
            .collection(FirestoreCollections.appSettings)
            .doc('superAdminCreated');
        final superAdminSnapshot = await transaction.get(superAdminRef);
        final isSuperAdmin = isSuperAdminLogin(normalizedLogin);
        final isTrustedAdmin = isTrustedAdminLogin(normalizedLogin);
        final adminBootstrapRef = _firestore
            .collection(FirestoreCollections.appSettings)
            .doc('adminBootstrap_$normalizedLogin');
        final adminBootstrapSnapshot = isSuperAdmin
            ? await transaction.get(adminBootstrapRef)
            : null;
        final shouldActivateSuperAdmin = isSuperAdmin;

        DocumentReference<Map<String, dynamic>>? inviteRef;
        DocumentSnapshot<Map<String, dynamic>>? inviteSnapshot;
        final inviteCode = TextUtils.normalizeInviteCode(data.inviteCode);
        if (!skipsInviteCode(normalizedLogin)) {
          if (inviteCode.isEmpty) {
            throw StateError('Podaj kod zaproszenia.');
          }
          inviteRef = _firestore
              .collection(FirestoreCollections.inviteCodes)
              .doc(inviteCode);
          inviteSnapshot = await transaction.get(inviteRef);
          if (!inviteSnapshot.exists) {
            throw StateError('Kod zaproszenia nie istnieje.');
          }
          final invite = inviteSnapshot.data() ?? {};
          final active = (invite['active'] as bool?) ?? false;
          final usedCount = (invite['usedCount'] as num?)?.toInt() ?? 0;
          final maxUses = (invite['maxUses'] as num?)?.toInt() ?? 1;
          if (!active || usedCount >= maxUses) {
            throw StateError('Kod zaproszenia jest nieaktywny lub wyczerpany.');
          }
        }

        final role = shouldActivateSuperAdmin ? UserRole.admin : UserRole.user;
        final accountStatus = shouldActivateSuperAdmin
            ? AccountStatus.active
            : AccountStatus.pending;
        final blockedWrite = accountStatus != AccountStatus.active;
        final isStartAdmin = normalizedLogin == AppConstants.superAdminLogin;
        final profileFirstName = isStartAdmin
            ? 'Sławomir'
            : data.firstName.trim();
        final profileLastName = isStartAdmin ? 'Badura' : data.lastName.trim();
        final profileNickname = isStartAdmin
            ? 'Sławomir Badura'
            : data.nickname.trim();
        final profileUnitType = isStartAdmin ? UnitType.osp : data.unitType;
        final profileUnitName = isStartAdmin
            ? 'OSP Gorzyce'
            : data.unitName.trim();
        final profileUnitId = TextUtils.normalizeId(profileUnitName);

        final appUser = AppUser(
          uid: createdUser!.uid,
          login: normalizedLogin,
          email: technicalEmail,
          firstName: profileFirstName,
          lastName: profileLastName,
          nickname: profileNickname,
          phoneNumber: data.phoneNumber.trim(),
          unitType: profileUnitType,
          unitId: profileUnitId,
          unitName: profileUnitName,
          voivodeship: data.voivodeship.trim().isEmpty
              ? AppConstants.defaultVoivodeship
              : data.voivodeship.trim(),
          county: data.county.trim().isEmpty
              ? AppConstants.defaultCounty
              : data.county.trim(),
          role: role,
          accountStatus: accountStatus,
          presenceStatus: PresenceStatus.offline,
          joinedAt: DateTime.now(),
          lastSeenAt: DateTime.now(),
          avatarUrl: avatarUrl,
          blockedWrite: blockedWrite,
          trustedAdminCandidate: isTrustedAdmin,
        );
        registeredUser = appUser;

        final userRef = _firestore
            .collection(FirestoreCollections.users)
            .doc(createdUser.uid);
        final unitRef = _firestore
            .collection(FirestoreCollections.units)
            .doc(profileUnitId);
        final userMap = {
          ...appUser.toMap(),
          'inviteCode': skipsInviteCode(normalizedLogin) ? null : inviteCode,
          'bootstrapAdmin': shouldActivateSuperAdmin,
          'trustedAdminCandidate': isTrustedAdmin,
          'adminNotes': data.adminNotes.trim(),
          'requestedUnitType': data.unitType.name,
          'requestedServiceType': data.unitType.label,
          'requestedUnitName': data.unitName.trim(),
        };

        transaction.set(userRef, userMap, SetOptions(merge: true));
        if (profileUnitId.isNotEmpty && profileUnitType.hasOwnUnitChat) {
          transaction.set(unitRef, {
            'id': profileUnitId,
            'name': profileUnitName,
            'type': profileUnitType.name,
            'voivodeship': appUser.voivodeship,
            'county': appUser.county,
            'createdAt': FieldValue.serverTimestamp(),
            'memberIds': FieldValue.arrayUnion([createdUser.uid]),
            'active': true,
          }, SetOptions(merge: true));
        }
        if (inviteRef != null) {
          transaction.update(inviteRef, {'usedCount': FieldValue.increment(1)});
        }
        if (shouldActivateSuperAdmin &&
            !(adminBootstrapSnapshot?.exists ?? false)) {
          transaction.set(adminBootstrapRef, {
            'created': true,
            'login': normalizedLogin,
            'createdAt': FieldValue.serverTimestamp(),
            'authUid': createdUser.uid,
          });
        }
        if (normalizedLogin == AppConstants.superAdminLogin &&
            !superAdminSnapshot.exists) {
          transaction.set(superAdminRef, {
            'created': true,
            'login': AppConstants.superAdminLogin,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });
      final appUser = registeredUser;
      if (appUser == null) {
        throw StateError('Nie udało się zapisać profilu użytkownika.');
      }
      _debugAuthProfile(
        uid: createdUser.uid,
        login: normalizedLogin,
        authEmail: technicalEmail,
        role: appUser.role,
        accountStatus: appUser.accountStatus,
      );
      return appUser;
    } on Object {
      if (createdUser != null && createdAuthUser) {
        await createdUser.delete().catchError((Object _) {});
      }
      rethrow;
    }
  }

  Future<AppUser> _createBootstrapAdminAccount({
    required String login,
    required String password,
  }) async {
    if (password.length < 6) {
      throw StateError('Hasło musi mieć minimum 6 znaków.');
    }

    final technicalEmail = technicalEmailForLogin(login);
    UserCredential? credential;
    AppUser? createdProfile;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: technicalEmail,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw StateError('Nie udało się aktywować konta administratora.');
      }

      final isSuperAdmin = login == AppConstants.superAdminLogin;
      final unitName = isSuperAdmin
          ? 'OSP Gorzyce'
          : 'Administrator Tarnobrzeg 112';
      final nickname = isSuperAdmin ? 'Sławomir Badura' : 'Robak Admin';
      final unitId = TextUtils.normalizeId(unitName);
      final appUser = AppUser(
        uid: user.uid,
        login: login,
        email: technicalEmail,
        firstName: isSuperAdmin ? 'Sławomir' : 'Robak',
        lastName: isSuperAdmin ? 'Badura' : 'Admin',
        nickname: nickname,
        phoneNumber: '',
        unitType: isSuperAdmin ? UnitType.osp : UnitType.inne,
        unitId: unitId,
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
      createdProfile = appUser;

      await _firestore.runTransaction((transaction) async {
        final adminBootstrapRef = _firestore
            .collection(FirestoreCollections.appSettings)
            .doc('adminBootstrap_$login');
        final adminBootstrapSnapshot = await transaction.get(adminBootstrapRef);

        final superAdminRef = _firestore
            .collection(FirestoreCollections.appSettings)
            .doc('superAdminCreated');
        final superAdminSnapshot = await transaction.get(superAdminRef);

        transaction.set(
          _firestore.collection(FirestoreCollections.users).doc(user.uid),
          {
            ...appUser.toMap(),
            'bootstrapAdmin': true,
            'trustedAdminCandidate': false,
            'mustSetPassword': false,
          },
          SetOptions(merge: true),
        );
        if (unitId.isNotEmpty && appUser.unitType.hasOwnUnitChat) {
          transaction.set(
            _firestore.collection(FirestoreCollections.units).doc(unitId),
            {
              'id': unitId,
              'name': unitName,
              'type': appUser.unitType.name,
              'voivodeship': AppConstants.defaultVoivodeship,
              'county': AppConstants.defaultCounty,
              'createdAt': FieldValue.serverTimestamp(),
              'memberIds': FieldValue.arrayUnion([user.uid]),
              'active': true,
            },
            SetOptions(merge: true),
          );
        }
        if (!adminBootstrapSnapshot.exists) {
          transaction.set(adminBootstrapRef, {
            'created': true,
            'login': login,
            'createdAt': FieldValue.serverTimestamp(),
            'authUid': user.uid,
          });
        }
        if (isSuperAdmin && !superAdminSnapshot.exists) {
          transaction.set(superAdminRef, {
            'created': true,
            'login': AppConstants.superAdminLogin,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });

      await _writeBootstrapLog(user.uid, login);
      _debugAuthProfile(
        uid: user.uid,
        login: login,
        authEmail: technicalEmail,
        role: UserRole.admin,
        accountStatus: AccountStatus.active,
      );
      return createdProfile;
    } on FirebaseAuthException catch (error) {
      _debugFirebaseAuthException('Bootstrap admin Auth failed', error);
      final createdUser = credential?.user;
      if (createdUser != null) {
        await createdUser.delete().catchError((Object _) {});
      }
      rethrow;
    } on Object {
      final createdUser = credential?.user;
      if (createdUser != null) {
        await createdUser.delete().catchError((Object _) {});
      }
      rethrow;
    }
  }

  Future<void> _writeBootstrapLog(String uid, String login) async {
    try {
      await _firestore.collection(FirestoreCollections.moderationLogs).add({
        'action': 'bootstrap_admin_created',
        'targetUserId': uid,
        'targetUserLogin': login,
        'performedBy': uid,
        'performedByLogin': login,
        'oldValue': null,
        'newValue': 'role=admin; accountStatus=active',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on Object {
      // Log startowy nie może blokować pierwszego wejścia admina.
    }
  }

  Future<AppUser?> _loadProfileAfterAuth({required User? firebaseUser}) async {
    if (firebaseUser == null) return null;
    debugPrint('AUTH DEBUG current UID=${firebaseUser.uid}');
    try {
      final uidSnapshot = await _firestore
          .collection(FirestoreCollections.users)
          .doc(firebaseUser.uid)
          .get();
      debugPrint(
        'AUTH DEBUG fetched document=users/${firebaseUser.uid} '
        'exists=${uidSnapshot.exists} data=${uidSnapshot.data()}',
      );
      if (uidSnapshot.exists) {
        final appUser = AppUser.fromSnapshot(uidSnapshot);
        debugPrint(
          'AUTH DEBUG accountStatus=${appUser.accountStatus.name} '
          'role=${appUser.role.name}',
        );
        return appUser;
      }
    } on FirebaseException catch (error) {
      debugPrint(
        'UID profile after Auth skipped: code=${error.code} message=${error.message}',
      );
    } on Object catch (error, stackTrace) {
      debugPrint('UID profile after Auth failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    return null;
  }

  void _debugFirebaseAuthException(String prefix, FirebaseAuthException error) {
    debugPrint(
      '$prefix: code=${error.code} message=${error.message} '
      'email=${error.email} credential=${error.credential}',
    );
  }

  void _debugAuthProfile({
    required String uid,
    required String login,
    required String authEmail,
    required UserRole role,
    required AccountStatus accountStatus,
  }) {
    debugPrint(
      'AUTH DEBUG uid=$uid login=$login authEmail=$authEmail '
      'role=${role.name} accountStatus=${accountStatus.name}',
    );
  }

  Future<void> sendPasswordReset(String login) {
    final normalizedLogin = TextUtils.normalizeLogin(login);
    return _auth.sendPasswordResetEmail(
      email: technicalEmailForLogin(normalizedLogin),
    );
  }

  Future<void> changePassword({
    required String login,
    required String currentPassword,
    required String newPassword,
  }) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      throw StateError('Brak aktywnej sesji użytkownika.');
    }
    if (newPassword.length < 6) {
      throw StateError('Nowe hasło musi mieć minimum 6 znaków.');
    }

    final normalizedLogin = TextUtils.normalizeLogin(login);
    final authEmail = firebaseUser.email?.trim().isNotEmpty == true
        ? firebaseUser.email!.trim()
        : technicalEmailForLogin(normalizedLogin);
    try {
      final credential = EmailAuthProvider.credential(
        email: authEmail,
        password: currentPassword,
      );
      await firebaseUser.reauthenticateWithCredential(credential);
      await firebaseUser.updatePassword(newPassword);
      debugPrint(
        'AUTH DEBUG password changed uid=${firebaseUser.uid} '
        'login=$normalizedLogin authEmail=$authEmail',
      );
    } on FirebaseAuthException catch (error) {
      _debugFirebaseAuthException('Password change failed', error);
      rethrow;
    } on Object catch (error, stackTrace) {
      debugPrint('Password change unexpected error: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> signOut({String reason = 'manual'}) {
    final user = _auth.currentUser;
    debugPrint(
      'AUTH DEBUG signOut called reason=$reason uid=${user?.uid ?? '-'} '
      'email=${user?.email ?? '-'}',
    );
    return _auth.signOut();
  }

  static String technicalEmailForLogin(String login) {
    return '$login@${AppConstants.technicalEmailDomain}';
  }

  static bool isSuperAdminLogin(String login) {
    return TextUtils.normalizeLogin(login) == AppConstants.superAdminLogin;
  }

  static bool isTrustedAdminLogin(String login) {
    return AppConstants.trustedAdminLogins.contains(
      TextUtils.normalizeLogin(login),
    );
  }

  static bool skipsInviteCode(String login) {
    return isSuperAdminLogin(login) || isTrustedAdminLogin(login);
  }
}
