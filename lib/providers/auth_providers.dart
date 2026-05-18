import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges().map((user) {
    debugPrint('AUTH DEBUG authStateChanges user.uid=${user?.uid ?? '-'}');
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
        debugPrint(
          'AUTH DEBUG current UID=${firebaseUser.uid} '
          'login=${user?.login ?? '-'} '
          'authEmail=${firebaseUser.email ?? '-'} '
          'role=${user?.role.name ?? '-'} '
          'accountStatus=${user?.accountStatus.name ?? '-'}',
        );
        return user;
      });
});

final pendingUsersProvider = StreamProvider<List<AppUser>>((ref) {
  return ref
      .watch(usersRepositoryProvider)
      .watchUsers(status: AccountStatus.pending);
});

final allUsersProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(usersRepositoryProvider).watchUsers();
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
