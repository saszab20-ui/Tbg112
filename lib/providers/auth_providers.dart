import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';

class UserStats {
  const UserStats({
    required this.total,
    required this.pending,
    required this.active,
    required this.blocked,
    required this.muted,
  });

  final int total;
  final int pending;
  final int active;
  final int blocked;
  final int muted;

  factory UserStats.fromUsers(List<AppUser> users) {
    final realUsers = users.where(_isRealUser).toList();
    return UserStats(
      total: realUsers.length,
      pending: realUsers
          .where((user) => user.accountStatus == AccountStatus.pending)
          .length,
      active: realUsers
          .where((user) => user.accountStatus == AccountStatus.active)
          .length,
      blocked: realUsers
          .where(
            (user) =>
                user.accountStatus == AccountStatus.banned ||
                user.accountStatus == AccountStatus.suspended,
          )
          .length,
      muted: realUsers.where((user) => user.isMuted).length,
    );
  }

  static bool _isRealUser(AppUser user) {
    final login = user.login.trim().toLowerCase();
    final nickname = user.nickname.trim().toLowerCase();
    if (user.uid.trim().isEmpty) return false;
    if (user.accountStatus == AccountStatus.deleted) return false;
    if (login.isEmpty && nickname.isEmpty) return false;
    return !login.startsWith('qa_') &&
        !login.startsWith('test_') &&
        !login.startsWith('placeholder') &&
        !nickname.startsWith('qa ') &&
        !nickname.startsWith('test ');
  }
}

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges().map((user) {
    if (kDebugMode) {
      debugPrint('AUTH DEBUG authStateChanges user.uid=${user?.uid ?? '-'}');
    }
    return user;
  });
});

final currentAppUserProvider = StreamProvider<AppUser?>((ref) {
  final authState = ref.watch(authStateProvider);
  final firebaseUser = authState.asData?.value;
  if (firebaseUser == null) return Stream.value(null);
  return ref
      .watch(usersRepositoryProvider)
      .watchAuthenticatedUser(
        authUid: firebaseUser.uid,
        authEmail: firebaseUser.email,
      )
      .map((user) {
        if (kDebugMode) {
          debugPrint(
            'AUTH DEBUG profile ready uid=${firebaseUser.uid} '
            'role=${user?.role.name ?? '-'} '
            'accountStatus=${user?.accountStatus.name ?? '-'}',
          );
        }
        return user;
      });
});

final pendingUsersProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(usersRepositoryProvider).watchPendingUsers();
});

final allUsersProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(usersRepositoryProvider).watchUsers();
});

final userStatsProvider = StreamProvider<UserStats>((ref) {
  return ref
      .watch(usersRepositoryProvider)
      .watchUsers(limit: 1000)
      .map(UserStats.fromUsers);
});

final activeUsersProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(usersRepositoryProvider).watchActiveUsers();
});

final unitActiveUsersProvider = StreamProvider.family<List<AppUser>, String>((
  ref,
  unitId,
) {
  return ref.watch(usersRepositoryProvider).watchActiveUsers(unitId: unitId);
});

final activeUnitNamesProvider = StreamProvider<List<String>>((ref) {
  return ref.watch(usersRepositoryProvider).watchActiveUnitNames();
});

final mutedUsersProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(usersRepositoryProvider).watchMutedUsers();
});
