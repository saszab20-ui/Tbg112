import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/core/firestore_collections.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:tarnobrzeg112/models/chat_message.dart';
import 'package:tarnobrzeg112/models/private_chat.dart';
import 'package:tarnobrzeg112/models/private_message.dart';
import 'package:tarnobrzeg112/services/storage_service.dart';
import 'package:uuid/uuid.dart';

class PrivateChatRepository {
  PrivateChatRepository(this._firestore, this._storageService);

  final FirebaseFirestore _firestore;
  final StorageService _storageService;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _chats =>
      _firestore.collection(FirestoreCollections.chats);

  Stream<List<PrivateChat>> watchChats(String uid) {
    return _chats
        .where('participants', arrayContains: uid)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          final chats =
              snapshot.docs
                  .map(PrivateChat.fromSnapshot)
                  .where(
                    (chat) =>
                        (chat.chatKind == 'private' || chat.isGroup) &&
                        !chat.isArchived &&
                        !chat.isExpired &&
                        !chat.hiddenFor.contains(uid),
                  )
                  .toList()
                ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return chats;
        });
  }

  Stream<PrivateChat?> watchChat(String chatId) {
    return _chats.doc(chatId).snapshots().map((doc) {
      if (!doc.exists) return null;
      final chat = PrivateChat.fromSnapshot(doc);
      if (chat.isExpired) return null;
      return chat;
    });
  }

  Stream<List<PrivateChat>> watchGroups(AppUser user) {
    final query = _chats
        .where('participants', arrayContains: user.uid)
        .limit(50);
    return query.snapshots().map((snapshot) {
      final groups =
          snapshot.docs
              .map(PrivateChat.fromSnapshot)
              .where(
                (chat) => chat.isGroup && !chat.isArchived && !chat.isExpired,
              )
              .toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return groups;
    });
  }

  Stream<List<PrivateMessage>> watchMessages(String chatId) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(PrivateMessage.fromSnapshot).toList(),
        );
  }

  Future<String> openChat(AppUser current, AppUser other) async {
    final ids = [current.uid, other.uid]..sort();
    final chatId = 'private_${ids.join('_')}';
    final chatRef = _chats.doc(chatId);
    final existing = await chatRef.get();
    if (existing.exists) {
      final data = existing.data();
      final existingJoinedAt = data?['joinedAt'];
      final existingParticipants = _stringList(
        data?['participants'] ?? data?['participantIds'],
      );
      final hiddenFor = _stringList(data?['hiddenFor']);
      final currentAlreadyJoined =
          existingJoinedAt is Map && existingJoinedAt.containsKey(current.uid);
      if (existingParticipants.contains(current.uid) &&
          existingParticipants.contains(other.uid) &&
          currentAlreadyJoined &&
          !hiddenFor.contains(current.uid)) {
        return chatId;
      }
      final update = <String, Object?>{
        'participants': FieldValue.arrayUnion(ids),
        'participantIds': FieldValue.arrayUnion(ids),
        'participantLogins': FieldValue.arrayUnion([
          current.login,
          other.login,
        ]),
        'participantNameMap.${current.uid}': current.publicName,
        'participantNameMap.${other.uid}': other.publicName,
        'hiddenFor': FieldValue.arrayRemove([current.uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      var addedJoinNotice = false;
      if (existingJoinedAt is! Map ||
          !existingJoinedAt.containsKey(current.uid)) {
        update['joinedAt.${current.uid}'] = FieldValue.serverTimestamp();
        addedJoinNotice = true;
      }
      if (existingJoinedAt is! Map ||
          !existingJoinedAt.containsKey(other.uid)) {
        update['joinedAt.${other.uid}'] = FieldValue.serverTimestamp();
      }
      if (!addedJoinNotice) {
        await chatRef.set(update, SetOptions(merge: true));
        return chatId;
      }
      // If we added joinedAt for the current user, write it together with a
      // one-off system message visible only to that user.
      final batch = _firestore.batch();
      batch.set(chatRef, update, SetOptions(merge: true));
      final msgId = 'joined_notice_${current.uid}_${_uuid.v4()}';
      final joinMsg = ChatMessage(
        id: msgId,
        chatId: chatId,
        scope: ChatScope.private,
        senderId: 'system',
        senderLogin: 'system',
        senderDisplayName: 'System',
        senderUnitName: '',
        text: 'Dołączyłeś do czatu',
        createdAt: DateTime.now(),
        visibleTo: [current.uid],
        participants: [current.uid],
      );
      batch.set(chatRef.collection('messages').doc(msgId), joinMsg.toMap());
      await batch.commit();
      return chatId;
    }
    final participantNames = {
      current.uid: current.publicName,
      other.uid: other.publicName,
    };
    await chatRef.set({
      'id': chatId,
      'type': 'private',
      'chatKind': 'private',
      'name': '',
      'createdBy': current.uid,
      'ownerId': current.uid,
      'participants': ids,
      'participantIds': ids,
      'participantLogins': [current.login, other.login]..sort(),
      'participantNames': ids.map((id) => participantNames[id]).toList(),
      'participantNameMap': participantNames,
      'joinedAt': {
        for (final uid in ids) uid: Timestamp.fromDate(DateTime.now()),
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'isArchived': false,
      'visibilityMode': 'unlimited',
      'expiresAt': null,
      'unreadCount': {for (final uid in ids) uid: 0},
    }, SetOptions(merge: true));
    return chatId;
  }

  Future<String> createGroupChat({
    required AppUser owner,
    required String name,
    required List<AppUser> participants,
  }) async {
    final cleanName = name.trim();
    if (cleanName.length < 3) {
      throw StateError('Nazwa grupy musi mieć minimum 3 znaki.');
    }
    final allParticipants = <AppUser>[
      owner,
      ...participants.where((user) => user.uid != owner.uid),
    ];
    final participantIds =
        allParticipants.map((user) => user.uid).toSet().toList()..sort();
    final byId = {for (final user in allParticipants) user.uid: user};
    final participantNames = {
      for (final uid in participantIds) uid: byId[uid]?.publicName ?? uid,
    };
    final participantLogins = [
      for (final uid in participantIds) byId[uid]?.login ?? uid,
    ];
    final chatId = 'group_${_uuid.v4()}';
    final batch = _firestore.batch();
    final now = Timestamp.fromDate(DateTime.now());
    batch.set(_chats.doc(chatId), {
      'id': chatId,
      'type': 'group',
      'chatKind': 'group',
      'name': cleanName,
      'createdBy': owner.uid,
      'ownerId': owner.uid,
      'participants': participantIds,
      'participantIds': participantIds,
      'participantLogins': participantLogins,
      'participantNames': participantIds
          .map((uid) => participantNames[uid] ?? uid)
          .toList(),
      'participantNameMap': participantNames,
      'joinedAt': {for (final uid in participantIds) uid: now},
      'themeColor': '#ff3b30',
      'messageStyle': 'rounded',
      'chatTheme': 'default',
      'backgroundType': 'preset',
      'backgroundPreset': 'default',
      'backgroundImageUrl': '',
      'incomingSound': 'unique_sms',
      'privateSound': 'cool_sms_tone',
      'vibrationEnabled': true,
      'notificationMode': 'loud',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'isArchived': false,
      'visibilityMode': 'unlimited',
      'expiresAt': null,
      'unreadCount': {for (final uid in participantIds) uid: 0},
      'typing': {for (final uid in participantIds) uid: false},
    });
    await batch.commit();
    return chatId;
  }

  Future<void> updateGroupParticipants({
    required PrivateChat chat,
    required AppUser actor,
    required List<AppUser> participants,
  }) {
    if (!_canManageMembers(actor, chat)) {
      throw StateError('Nie masz uprawnień do zmiany składu tego czatu.');
    }
    final participantIds = participants.map((user) => user.uid).toSet().toList()
      ..sort();
    if (!participantIds.contains(chat.ownerId)) {
      participantIds.add(chat.ownerId);
    }
    final participantNames = {
      ...chat.participantNames,
      for (final user in participants) user.uid: user.publicName,
    };
    final participantLogins = {
      for (final user in participants) user.uid: user.login,
    };
    final update = <String, Object?>{
      'participants': participantIds,
      'participantIds': participantIds,
      'participantLogins': participantIds
          .map((uid) => participantLogins[uid] ?? uid)
          .toList(),
      'participantNames': participantIds
          .map((uid) => participantNames[uid] ?? uid)
          .toList(),
      'participantNameMap': participantNames,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    for (final uid in participantIds) {
      if (participantNames.containsKey(uid)) {
        update['participantNameMap.$uid'] = participantNames[uid];
      }
    }
    final newJoins = <String>[];
    for (final uid in participantIds) {
      if (!chat.participantIds.contains(uid)) newJoins.add(uid);
    }
    for (final uid in newJoins) {
      update['joinedAt.$uid'] = FieldValue.serverTimestamp();
      update['unreadCount.$uid'] = 0;
      update['typing.$uid'] = false;
    }
    if (newJoins.isNotEmpty) {
      update['hiddenFor'] = FieldValue.arrayRemove(newJoins);
    }
    final batch = _firestore.batch();
    batch.set(_chats.doc(chat.id), update, SetOptions(merge: true));
    for (final uid in newJoins) {
      final msgId = 'joined_notice_${uid}_${_uuid.v4()}';
      final joinMsg = ChatMessage(
        id: msgId,
        chatId: chat.id,
        scope: ChatScope.group,
        senderId: 'system',
        senderLogin: 'system',
        senderDisplayName: 'System',
        senderUnitName: '',
        text: 'Dołączyłeś do czatu',
        createdAt: DateTime.now(),
        visibleTo: [uid],
        participants: [uid],
      );
      batch.set(
        _chats.doc(chat.id).collection('messages').doc(msgId),
        joinMsg.toMap(),
      );
    }
    return batch.commit();
  }

  Future<void> addParticipant({
    required PrivateChat chat,
    required AppUser actor,
    required AppUser user,
  }) {
    if (!_canManageMembers(actor, chat)) {
      throw StateError('Nie masz uprawnień do dodawania osób do tego czatu.');
    }
    if (chat.participantIds.contains(user.uid)) return Future.value();
    final batch = _firestore.batch();
    final chatRef = _chats.doc(chat.id);
    batch.set(chatRef, {
      'participants': FieldValue.arrayUnion([user.uid]),
      'participantIds': FieldValue.arrayUnion([user.uid]),
      'participantLogins': FieldValue.arrayUnion([user.login]),
      'participantNames': FieldValue.arrayUnion([user.publicName]),
      'participantNameMap.${user.uid}': user.publicName,
      'joinedAt.${user.uid}': FieldValue.serverTimestamp(),
      'unreadCount.${user.uid}': 0,
      'typing.${user.uid}': false,
      'hiddenFor': FieldValue.arrayRemove([user.uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final msgId = 'joined_notice_${user.uid}_${_uuid.v4()}';
    final joinMsg = ChatMessage(
      id: msgId,
      chatId: chat.id,
      scope: ChatScope.group,
      senderId: 'system',
      senderLogin: 'system',
      senderDisplayName: 'System',
      senderUnitName: '',
      text: 'Dołączyłeś do czatu',
      createdAt: DateTime.now(),
      visibleTo: [user.uid],
      participants: [user.uid],
    );
    batch.set(chatRef.collection('messages').doc(msgId), joinMsg.toMap());
    return batch.commit();
  }

  Future<void> updateChatSettings({
    required PrivateChat chat,
    required AppUser actor,
    required String name,
    required String themeColor,
    required String messageStyle,
    required String chatTheme,
    required String backgroundType,
    required String backgroundPreset,
    required String incomingSound,
    required String privateSound,
    required bool vibrationEnabled,
    required String notificationMode,
    String? backgroundImageUrl,
  }) {
    if (!actor.isAdmin && actor.uid != chat.ownerId) {
      throw StateError('Tylko właściciel grupy albo admin może zmieniać czat.');
    }
    final update = <String, Object?>{
      'name': name.trim().isEmpty ? chat.name : name.trim(),
      'themeColor': themeColor,
      'messageStyle': messageStyle,
      'chatTheme': chatTheme,
      'backgroundType': backgroundType,
      'backgroundPreset': backgroundPreset,
      'incomingSound': incomingSound,
      'privateSound': privateSound,
      'vibrationEnabled': vibrationEnabled,
      'notificationMode': notificationMode,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (backgroundImageUrl != null) {
      update['backgroundImageUrl'] = backgroundImageUrl;
    }
    return _chats.doc(chat.id).set(update, SetOptions(merge: true));
  }

  Future<void> updateVisibilityMode({
    required PrivateChat chat,
    required AppUser actor,
    required String visibilityMode,
  }) {
    if (!chat.participantIds.contains(actor.uid) && !actor.isAdmin) {
      throw StateError('Nie masz dostępu do tej rozmowy.');
    }
    final normalized = visibilityMode == '24h' ? '24h' : 'unlimited';
    return _chats.doc(chat.id).set({
      'visibilityMode': normalized,
      'expiresAt': normalized == '24h'
          ? Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24)))
          : null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateChatName({
    required PrivateChat chat,
    required AppUser actor,
    required String name,
  }) {
    if (!actor.isAdmin && actor.uid != chat.ownerId) {
      throw StateError(
        'Tylko właściciel grupy albo admin może zmieniać nazwę.',
      );
    }
    return _chats.doc(chat.id).set({
      'name': name.trim().isEmpty ? chat.name : name.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeParticipant({
    required PrivateChat chat,
    required AppUser actor,
    required String uid,
  }) {
    if (!_canManageMembers(actor, chat)) {
      throw StateError('Nie masz uprawnień do usuwania osób z tego czatu.');
    }
    return _chats.doc(chat.id).set({
      'participants': FieldValue.arrayRemove([uid]),
      'participantIds': FieldValue.arrayRemove([uid]),
      'hiddenFor': FieldValue.arrayUnion([uid]),
      'unreadCount.$uid': FieldValue.delete(),
      'typing.$uid': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  bool _canManageMembers(AppUser actor, PrivateChat chat) {
    return actor.isAdmin ||
        actor.uid == chat.ownerId ||
        actor.moderatorCan('manageChatMembers');
  }

  Future<void> hideChatForUser({
    required PrivateChat chat,
    required AppUser user,
  }) {
    if (!chat.participantIds.contains(user.uid) && !user.isAdmin) {
      throw StateError('Nie masz dostępu do tej rozmowy.');
    }
    return _chats.doc(chat.id).set({
      'hiddenFor': FieldValue.arrayUnion([user.uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> clearHistoryForUser({
    required PrivateChat chat,
    required AppUser user,
  }) {
    if (!chat.participantIds.contains(user.uid) && !user.isAdmin) {
      throw StateError('Nie masz dostępu do tej rozmowy.');
    }
    return _chats.doc(chat.id).set({
      'clearedAt.${user.uid}': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> leaveGroup({required PrivateChat chat, required AppUser user}) {
    if (!chat.isGroup) {
      throw StateError('To nie jest czat grupowy.');
    }
    if (chat.ownerId == user.uid && chat.participantIds.length > 1) {
      throw StateError(
        'Właściciel musi najpierw usunąć grupę albo przekazać dostęp.',
      );
    }
    return _chats.doc(chat.id).set({
      'participants': FieldValue.arrayRemove([user.uid]),
      'participantIds': FieldValue.arrayRemove([user.uid]),
      'participantLogins': FieldValue.arrayRemove([user.login]),
      'participantNames': FieldValue.arrayRemove([user.publicName]),
      'participantNameMap.${user.uid}': FieldValue.delete(),
      'joinedAt.${user.uid}': FieldValue.delete(),
      'unreadCount.${user.uid}': FieldValue.delete(),
      'typing.${user.uid}': FieldValue.delete(),
      'hiddenFor': FieldValue.arrayUnion([user.uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> archiveGroup({
    required PrivateChat chat,
    required AppUser actor,
  }) async {
    final authUid = FirebaseAuth.instance.currentUser?.uid ?? actor.uid;
    if (!chat.isGroup) {
      throw StateError('To nie jest czat grupowy.');
    }
    if (!actor.isAdmin &&
        actor.uid != chat.ownerId &&
        authUid != chat.ownerId) {
      throw StateError('Tylko właściciel grupy albo admin może usunąć grupę.');
    }
    await _chats.doc(chat.id).set({
      'isArchived': true,
      'archivedAt': FieldValue.serverTimestamp(),
      'archivedBy': authUid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    try {
      await _deleteMessagesForChat(chat.id);
    } on Object {
      // The group is already archived; cleanup is best-effort.
    }
    try {
      await _deleteNotificationsForChat(chat.id);
    } on Object {
      // Notification cleanup must not block group removal from the UI.
    }
  }

  Future<void> sendMessage({
    required String chatId,
    required AppUser sender,
    required List<String> participantIds,
    String text = '',
    XFile? image,
  }) async {
    if (!sender.canWrite) {
      throw StateError('Konto nie ma teraz uprawnień do pisania.');
    }
    if (text.trim().isEmpty && image == null) return;
    final id = _uuid.v4();
    String? imageUrl;
    final attachments = <MessageAttachment>[];
    var mediaType = ChatMediaType.text;
    if (image != null) {
      imageUrl = await _storageService.uploadChatImage(
        chatPath: 'private/$chatId',
        file: image,
      );
      mediaType = ChatMediaType.image;
      attachments.add(
        MessageAttachment(
          url: imageUrl,
          mediaType: ChatMediaType.image,
          fileName: image.name,
          contentType: image.mimeType ?? 'image/jpeg',
        ),
      );
    }
    final message = ChatMessage(
      id: id,
      chatId: chatId,
      scope: ChatScope.private,
      senderId: sender.uid,
      senderLogin: sender.login,
      senderDisplayName: sender.publicName,
      senderUnitName: sender.unitName,
      text: text.trim(),
      imageUrl: imageUrl,
      attachments: attachments,
      mediaType: mediaType,
      createdAt: DateTime.now(),
      visibleTo: participantIds,
      participants: participantIds,
    );
    final batch = _firestore.batch();
    batch.set(
      _chats.doc(chatId).collection('messages').doc(id),
      message.toMap(),
    );
    // Increment unread only for participants who joined before this message,
    // exclude sender, system messages, and deleted messages.
    final unread = <String, Object>{};
    final chatSnapshot = await _chats.doc(chatId).get();
    final joinedMap = chatSnapshot.data()?['joinedAt'];
    for (final uid in participantIds.where((id) => id != sender.uid)) {
      final joinedTs = joinedMap is Map ? joinedMap[uid] : null;
      DateTime? joinedDate;
      if (joinedTs is Timestamp) joinedDate = joinedTs.toDate();
      if (joinedDate == null) continue;
      if (!message.createdAt.isAfter(joinedDate)) continue;
      unread['unreadCount.$uid'] = FieldValue.increment(1);
    }
    batch.set(_chats.doc(chatId), {
      'lastMessage': text.trim().isEmpty ? 'Zdjęcie' : text.trim(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      ...unread,
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> markRead(String chatId, String uid) {
    return _chats.doc(chatId).set({
      'unreadCount.$uid': 0,
      'deliveredReceipts.$uid': FieldValue.serverTimestamp(),
      'readReceipts.$uid': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markDelivered(String chatId, String uid) {
    return _chats.doc(chatId).set({
      'deliveredReceipts.$uid': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _deleteMessagesForChat(String chatId) async {
    final messages = _chats.doc(chatId).collection('messages');
    while (true) {
      final snapshot = await messages.limit(300).get();
      if (snapshot.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snapshot.docs.length < 300) return;
    }
  }

  Future<void> _deleteNotificationsForChat(String chatId) async {
    final notifications = _firestore.collection(
      FirestoreCollections.notifications,
    );
    final queries = [
      notifications.where('chatId', isEqualTo: chatId).limit(300),
      notifications.where('data.chatId', isEqualTo: chatId).limit(300),
    ];
    for (final query in queries) {
      try {
        while (true) {
          final snapshot = await query.get();
          if (snapshot.docs.isEmpty) break;
          final batch = _firestore.batch();
          for (final doc in snapshot.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
          if (snapshot.docs.length < 300) break;
        }
      } on FirebaseException {
        // Notifications are best-effort cleanup. A missing composite index or
        // an older document shape must not block deleting the group itself.
      }
    }
  }

  Future<void> setTyping(String chatId, String uid, bool typing) {
    return _chats.doc(chatId).collection('typing').doc(uid).set({
      'uid': uid,
      'typing': typing,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  List<String> _stringList(Object? value) {
    if (value is List) {
      return value
          .where((item) => item != null)
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) return [value.trim()];
    return const [];
  }
}
