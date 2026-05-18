import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tarnobrzeg112/repositories/auth_repository.dart';
import 'package:tarnobrzeg112/repositories/chat_repository.dart';
import 'package:tarnobrzeg112/repositories/moderation_repository.dart';
import 'package:tarnobrzeg112/repositories/notifications_repository.dart';
import 'package:tarnobrzeg112/repositories/private_chat_repository.dart';
import 'package:tarnobrzeg112/repositories/units_repository.dart';
import 'package:tarnobrzeg112/repositories/users_repository.dart';
import 'package:tarnobrzeg112/services/notification_service.dart';
import 'package:tarnobrzeg112/services/storage_service.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

final firebaseMessagingProvider = Provider<FirebaseMessaging>((ref) {
  return FirebaseMessaging.instance;
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(ref.watch(firebaseStorageProvider));
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(firebaseMessagingProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
    ref.watch(storageServiceProvider),
  );
});

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository(
    ref.watch(firestoreProvider),
    ref.watch(storageServiceProvider),
  );
});

final unitsRepositoryProvider = Provider<UnitsRepository>((ref) {
  return UnitsRepository(ref.watch(firestoreProvider));
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    ref.watch(firestoreProvider),
    ref.watch(storageServiceProvider),
  );
});

final privateChatRepositoryProvider = Provider<PrivateChatRepository>((ref) {
  return PrivateChatRepository(
    ref.watch(firestoreProvider),
    ref.watch(storageServiceProvider),
  );
});

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  return NotificationsRepository(ref.watch(firestoreProvider));
});

final moderationRepositoryProvider = Provider<ModerationRepository>((ref) {
  return ModerationRepository(ref.watch(firestoreProvider));
});
