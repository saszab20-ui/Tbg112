import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/core/firestore_collections.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:tarnobrzeg112/models/chat_message.dart';
import 'package:tarnobrzeg112/models/private_chat.dart';
import 'package:tarnobrzeg112/models/private_message.dart';
import 'package:tarnobrzeg112/services/storage_service.dart';
import 'package:tarnobrzeg112/utils/text_utils.dart';
import 'package:uuid/uuid.dart';

class GroupChatCreationResult {
  const GroupChatCreationResult({
    required this.chatId,
    required this.inviteCode,
    required this.inviteLink,
  });

  final String chatId;
  final String inviteCode;
  final String inviteLink;
}

class PrivateChatRepository {
  PrivateChatRepository(this._firestore, this._storageService);

  final FirebaseFirestore _firestore;
  final StorageService _storageService;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _chats =>
      _firestore.collection(FirestoreCollections.chats);

  CollectionReference<Map<String, dynamic>> get _invites =>
      _firestore.collection(FirestoreCollections.invites);

  Stream<List<PrivateChat>> watchChats(String uid) {
    return _chats
        .where('participants', arrayContains: uid)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          final chats =
              snapshot.docs
                  .map(PrivateChat.fromSnapshot)
                  .where((chat) => chat.chatKind == 'private' || chat.isGroup)
                  .toList()
                ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return chats;
        });
  }

  Stream<PrivateChat?> watchChat(String chatId) {
    return _chats.doc(chatId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return PrivateChat.fromSnapshot(doc);
    });
  }

  Stream<List<PrivateChat>> watchGroups(AppUser user) {
    final query = user.isAdmin
        ? _chats.where('type', isEqualTo: 'group').limit(100)
        : _chats.where('participants', arrayContains: user.uid).limit(50);
    return query.snapshots().map((snapshot) {
      final groups =
          snapshot.docs
              .map(PrivateChat.fromSnapshot)
              .where((chat) => chat.isGroup)
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
    final participantNames = {
      current.uid: current.publicName,
      other.uid: other.publicName,
    };
    await _chats.doc(chatId).set({
      'id': chatId,
      'type': 'private',
      'chatKind': 'private',
      'name': '',
      'createdBy': ids.first,
      'ownerId': ids.first,
      'participants': ids,
      'participantIds': ids,
      'participantLogins': [current.login, other.login]..sort(),
      'participantNames': ids.map((id) => participantNames[id]).toList(),
      'participantNameMap': participantNames,
      'updatedAt': FieldValue.serverTimestamp(),
      'isArchived': false,
    }, SetOptions(merge: true));
    return chatId;
  }

  Future<GroupChatCreationResult> createGroupChat({
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
    final invite = _newInviteCode();
    final link = 'tarnobrzeg112://chat/invite/$invite';
    final batch = _firestore.batch();
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
      'inviteCode': invite,
      'inviteLink': link,
      'themeColor': '#ff3b30',
      'backgroundType': 'preset',
      'backgroundPreset': 'default',
      'backgroundImageUrl': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'isArchived': false,
      'unreadCount': {for (final uid in participantIds) uid: 0},
      'typing': {for (final uid in participantIds) uid: false},
    });
    batch.set(_invites.doc(invite), {
      'inviteCode': invite,
      'chatId': chatId,
      'chatName': cleanName,
      'createdBy': owner.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30)),
      ),
      'maxUses': 100,
      'usedCount': 0,
      'usedBy': <String>[],
      'active': true,
    });
    await batch.commit();
    return GroupChatCreationResult(
      chatId: chatId,
      inviteCode: invite,
      inviteLink: link,
    );
  }

  Future<GroupChatCreationResult> createInviteLink({
    required PrivateChat chat,
    required AppUser actor,
  }) async {
    if (!actor.isAdmin && actor.uid != chat.ownerId) {
      throw StateError('Tylko właściciel grupy albo admin może tworzyć link.');
    }
    final invite = _newInviteCode();
    final link = 'tarnobrzeg112://chat/invite/$invite';
    final batch = _firestore.batch();
    batch.set(_invites.doc(invite), {
      'inviteCode': invite,
      'chatId': chat.id,
      'chatName': chat.displayNameFor(actor.uid),
      'createdBy': actor.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30)),
      ),
      'maxUses': 100,
      'usedCount': 0,
      'usedBy': <String>[],
      'active': true,
    });
    batch.set(_chats.doc(chat.id), {
      'inviteCode': invite,
      'inviteLink': link,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
    return GroupChatCreationResult(
      chatId: chat.id,
      inviteCode: invite,
      inviteLink: link,
    );
  }

  Future<String> joinByInvite({
    required String inviteCode,
    required AppUser user,
  }) async {
    final code = TextUtils.normalizeInviteCode(inviteCode);
    return _firestore.runTransaction((transaction) async {
      final inviteRef = _invites.doc(code);
      final inviteDoc = await transaction.get(inviteRef);
      if (!inviteDoc.exists) {
        throw StateError('Link zaproszenia nie istnieje.');
      }
      final invite = inviteDoc.data() ?? {};
      final active = (invite['active'] as bool?) ?? false;
      final usedBy = List<String>.from((invite['usedBy'] as List?) ?? const []);
      final maxUses = (invite['maxUses'] as num?)?.toInt() ?? 1;
      final expiresAt = invite['expiresAt'];
      final expiresDate = expiresAt is Timestamp ? expiresAt.toDate() : null;
      if (!active ||
          (expiresDate != null && expiresDate.isBefore(DateTime.now()))) {
        throw StateError('Link zaproszenia wygasł.');
      }
      if (!usedBy.contains(user.uid) && usedBy.length >= maxUses) {
        throw StateError('Limit użyć linku został wyczerpany.');
      }
      final chatId = (invite['chatId'] as String?) ?? '';
      if (chatId.isEmpty) {
        throw StateError('Link nie wskazuje czatu.');
      }
      final chatRef = _chats.doc(chatId);
      transaction.set(chatRef, {
        'participants': FieldValue.arrayUnion([user.uid]),
        'participantIds': FieldValue.arrayUnion([user.uid]),
        'participantLogins': FieldValue.arrayUnion([user.login]),
        'participantNames': FieldValue.arrayUnion([user.publicName]),
        'participantNameMap': {user.uid: user.publicName},
        'unreadCount.${user.uid}': 0,
        'typing.${user.uid}': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!usedBy.contains(user.uid)) {
        transaction.update(inviteRef, {
          'usedBy': FieldValue.arrayUnion([user.uid]),
          'usedCount': FieldValue.increment(1),
        });
      }
      return chatId;
    });
  }

  Future<void> updateGroupParticipants({
    required PrivateChat chat,
    required AppUser actor,
    required List<AppUser> participants,
  }) {
    if (!actor.isAdmin && actor.uid != chat.ownerId) {
      throw StateError(
        'Tylko właściciel grupy albo admin może zmieniać skład.',
      );
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
    return _chats.doc(chat.id).set({
      'participants': participantIds,
      'participantIds': participantIds,
      'participantNames': participantIds
          .map((uid) => participantNames[uid] ?? uid)
          .toList(),
      'participantNameMap': participantNames,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deactivateInvite({
    required PrivateChat chat,
    required AppUser actor,
  }) async {
    if (!actor.isAdmin && actor.uid != chat.ownerId) {
      throw StateError('Tylko właściciel grupy albo admin może wyłączyć link.');
    }
    final code = chat.inviteCode;
    final batch = _firestore.batch();
    if (code != null && code.isNotEmpty) {
      batch.set(_invites.doc(code), {'active': false}, SetOptions(merge: true));
    }
    batch.set(_chats.doc(chat.id), {
      'inviteCode': null,
      'inviteLink': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> updateChatSettings({
    required PrivateChat chat,
    required AppUser actor,
    required String name,
    required String themeColor,
    required String backgroundType,
    required String backgroundPreset,
    String? backgroundImageUrl,
  }) {
    if (!actor.isAdmin && actor.uid != chat.ownerId) {
      throw StateError('Tylko właściciel grupy albo admin może zmieniać czat.');
    }
    final update = <String, Object?>{
      'name': name.trim().isEmpty ? chat.name : name.trim(),
      'themeColor': themeColor,
      'backgroundType': backgroundType,
      'backgroundPreset': backgroundPreset,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (backgroundImageUrl != null) {
      update['backgroundImageUrl'] = backgroundImageUrl;
    }
    return _chats.doc(chat.id).set(update, SetOptions(merge: true));
  }

  Future<void> removeParticipant({
    required PrivateChat chat,
    required AppUser actor,
    required String uid,
  }) {
    if (!actor.isAdmin && actor.uid != chat.ownerId) {
      throw StateError('Tylko właściciel grupy albo admin może usuwać osoby.');
    }
    return _chats.doc(chat.id).set({
      'participants': FieldValue.arrayRemove([uid]),
      'participantIds': FieldValue.arrayRemove([uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
    final unread = <String, Object>{};
    for (final uid in participantIds.where((id) => id != sender.uid)) {
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
    }, SetOptions(merge: true));
  }

  Future<void> setTyping(String chatId, String uid, bool typing) {
    return _chats.doc(chatId).collection('typing').doc(uid).set({
      'uid': uid,
      'typing': typing,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _newInviteCode() {
    return _uuid.v4().split('-').first.toUpperCase();
  }
}
