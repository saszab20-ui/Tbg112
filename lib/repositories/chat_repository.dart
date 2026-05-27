import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tarnobrzeg112/core/app_constants.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/core/firestore_collections.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:tarnobrzeg112/models/chat_message.dart';
import 'package:tarnobrzeg112/models/pinned_message.dart';
import 'package:tarnobrzeg112/models/report_model.dart';
import 'package:tarnobrzeg112/models/typing_user.dart';
import 'package:tarnobrzeg112/services/storage_service.dart';
import 'package:tarnobrzeg112/utils/text_utils.dart';
import 'package:uuid/uuid.dart';

class ChatRepository {
  ChatRepository(this._firestore, this._storageService);

  final FirebaseFirestore _firestore;
  final StorageService _storageService;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _chats =>
      _firestore.collection(FirestoreCollections.chats);

  DocumentReference<Map<String, dynamic>> _chatRef(
    ChatScope scope,
    String chatId,
  ) {
    return _chats.doc(_canonicalChatId(scope, chatId));
  }

  CollectionReference<Map<String, dynamic>> _messagesRef(
    ChatScope scope,
    String chatId,
  ) {
    return _chatRef(scope, chatId).collection('messages');
  }

  Stream<List<ChatMessage>> watchMessages({
    required ChatScope scope,
    required String chatId,
    int limit = AppConstants.messagesPageSize,
  }) {
    return _messagesRef(scope, chatId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(ChatMessage.fromSnapshot).toList(),
        );
  }

  Stream<DateTime?> watchLastReadAt({
    required ChatScope scope,
    required String chatId,
    required String uid,
  }) {
    final canonicalChatId = _canonicalChatId(scope, chatId);
    return _chatRef(
      scope,
      canonicalChatId,
    ).collection('reads').doc(uid).snapshots().map((snapshot) {
      final value = snapshot.data()?['lastReadAt'];
      return value is Timestamp ? value.toDate() : null;
    });
  }

  Future<void> markRead({
    required ChatScope scope,
    required String chatId,
    required String uid,
    String? messageId,
  }) async {
    final canonicalChatId = _canonicalChatId(scope, chatId);
    final chatRef = _chatRef(scope, canonicalChatId);
    final batch = _firestore.batch();
    batch.set(chatRef.collection('reads').doc(uid), {
      'uid': uid,
      'chatId': canonicalChatId,
      'lastReadMessageId': messageId,
      'lastReadAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(chatRef, {
      'deliveredReceipts.$uid': FieldValue.serverTimestamp(),
      'readReceipts.$uid': FieldValue.serverTimestamp(),
      'lastReadMessageId.$uid': messageId,
      'unreadCount.$uid': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Stream<List<PinnedMessage>> watchPinnedMessages({
    required ChatScope scope,
    required String chatId,
  }) {
    final canonicalId = _canonicalChatId(scope, chatId);
    return _firestore
        .collection(FirestoreCollections.pinnedMessages)
        .where('chatScope', isEqualTo: scope.name)
        .where('chatId', isEqualTo: canonicalId)
        .orderBy('pinnedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(PinnedMessage.fromSnapshot).toList(),
        );
  }

  Future<void> sendMessage({
    required ChatScope scope,
    required String chatId,
    required AppUser sender,
    String text = '',
    XFile? image,
    XFile? video,
    PlatformFile? voice,
    PlatformFile? file,
    List<String> mentionIds = const [],
    ChatMessage? replyTo,
  }) async {
    if (!sender.canWrite) {
      throw StateError('Konto nie ma teraz uprawnień do pisania.');
    }
    if (text.trim().isEmpty &&
        image == null &&
        video == null &&
        voice == null &&
        file == null) {
      return;
    }

    final canonicalChatId = _canonicalChatId(scope, chatId);
    final hasMedia =
        image != null || video != null || voice != null || file != null;
    if (hasMedia) {
      final seedParticipants = await _participantsFor(
        scope: scope,
        chatId: canonicalChatId,
      );
      await _chatRef(scope, canonicalChatId).set(
        _chatMetadata(
          scope: scope,
          chatId: canonicalChatId,
          actor: sender,
          participants: seedParticipants,
          lastMessage: 'Załącznik',
        ),
        SetOptions(merge: true),
      );
    }
    final id = _uuid.v4();
    String? imageUrl;
    String? fileUrl;
    String? videoUrl;
    String? voiceUrl;
    final attachments = <MessageAttachment>[];
    var mediaType = text.trim().isEmpty
        ? ChatMediaType.file
        : ChatMediaType.text;

    if (image != null) {
      imageUrl = await _storageService.uploadChatImage(
        chatPath: '${scope.wireName}/$canonicalChatId',
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

    if (video != null) {
      videoUrl = await _storageService.uploadChatVideo(
        chatPath: '${scope.wireName}/$canonicalChatId',
        file: video,
      );
      mediaType = ChatMediaType.video;
      attachments.add(
        MessageAttachment(
          url: videoUrl,
          mediaType: ChatMediaType.video,
          fileName: video.name,
          contentType: video.mimeType ?? 'video/mp4',
        ),
      );
    }

    if (voice != null) {
      final bytes = voice.bytes;
      if (bytes == null) {
        throw StateError('Nie udało się odczytać głosówki.');
      }
      voiceUrl = await _storageService.uploadChatVoice(
        chatPath: '${scope.wireName}/$canonicalChatId',
        fileName: voice.name,
        bytes: bytes,
        contentType: _contentTypeForFile(voice, fallback: 'audio/mpeg'),
      );
      mediaType = ChatMediaType.voice;
      attachments.add(
        MessageAttachment(
          url: voiceUrl,
          mediaType: ChatMediaType.voice,
          fileName: voice.name,
          contentType: _contentTypeForFile(voice, fallback: 'audio/mpeg'),
          sizeBytes: voice.size,
        ),
      );
    }

    if (file != null) {
      final bytes = file.bytes;
      if (bytes == null) {
        throw StateError('Nie udało się odczytać pliku.');
      }
      final contentType = _contentTypeForFile(file);
      if (_isImageFile(file)) {
        imageUrl = await _storageService.uploadChatImageBytes(
          chatPath: '${scope.wireName}/$canonicalChatId',
          fileName: file.name,
          bytes: bytes,
          contentType: contentType,
        );
        mediaType = ChatMediaType.image;
        attachments.add(
          MessageAttachment(
            url: imageUrl,
            mediaType: ChatMediaType.image,
            fileName: file.name,
            contentType: contentType,
            sizeBytes: file.size,
          ),
        );
      } else if (_isAudioFile(file)) {
        voiceUrl = await _storageService.uploadChatVoice(
          chatPath: '${scope.wireName}/$canonicalChatId',
          fileName: file.name,
          bytes: bytes,
          contentType: contentType,
        );
        mediaType = ChatMediaType.voice;
        attachments.add(
          MessageAttachment(
            url: voiceUrl,
            mediaType: ChatMediaType.voice,
            fileName: file.name,
            contentType: contentType,
            sizeBytes: file.size,
          ),
        );
      } else {
        fileUrl = await _storageService.uploadChatFile(
          chatPath: '${scope.wireName}/$canonicalChatId',
          fileName: file.name,
          bytes: bytes,
          contentType: contentType,
        );
        mediaType = ChatMediaType.file;
        attachments.add(
          MessageAttachment(
            url: fileUrl,
            mediaType: ChatMediaType.file,
            fileName: file.name,
            contentType: contentType,
            sizeBytes: file.size,
          ),
        );
      }
    }

    final participants = await _participantsFor(
      scope: scope,
      chatId: canonicalChatId,
    );
    final message = ChatMessage(
      id: id,
      chatId: canonicalChatId,
      scope: scope,
      senderId: sender.uid,
      senderLogin: sender.login,
      senderDisplayName: sender.publicName,
      senderUnitName: sender.unitName,
      senderAvatarUrl: sender.avatarUrl,
      text: text.trim(),
      imageUrl: imageUrl,
      fileUrl: fileUrl ?? videoUrl ?? voiceUrl,
      fileName: file?.name ?? video?.name ?? voice?.name,
      attachments: attachments,
      mediaType: mediaType,
      replyToMessageId: replyTo?.id,
      replyPreview: replyTo?.userVisibleText,
      mentions: mentionIds
          .where((uid) => uid.isNotEmpty && uid != sender.uid)
          .toSet()
          .toList(),
      createdAt: DateTime.now(),
      visibleTo: participants,
      participants: participants,
    );

    final chatUpdate = _messageChatUpdate(
      scope: scope,
      chatId: canonicalChatId,
      actor: sender,
      participants: participants,
      lastMessage: text.trim().isEmpty ? mediaType.label : text.trim(),
    );

    final unreadUpdate = <String, Object>{};
    if (scope == ChatScope.group || scope == ChatScope.private) {
      final chatDoc = await _chatRef(scope, canonicalChatId).get();
      final joinedMap = chatDoc.data()?['joinedAt'];
      final clearedMap = chatDoc.data()?['clearedAt'];
      for (final uid in participants.where((id) => id != sender.uid)) {
        final joinedTs = joinedMap is Map ? joinedMap[uid] : null;
        DateTime? joinedDate;
        if (joinedTs is Timestamp) joinedDate = joinedTs.toDate();
        if (joinedDate == null) continue;
        if (!message.createdAt.isAfter(joinedDate)) continue;
        final clearedTs = clearedMap is Map ? clearedMap[uid] : null;
        if (clearedTs is Timestamp &&
            message.createdAt.isBefore(clearedTs.toDate())) {
          continue;
        }
        unreadUpdate['unreadCount.$uid'] = FieldValue.increment(1);
      }
    }

    await _messagesRef(scope, canonicalChatId).doc(id).set(message.toMap());

    await _chatRef(
      scope,
      canonicalChatId,
    ).set(chatUpdate, SetOptions(merge: true));

    if (unreadUpdate.isNotEmpty) {
      try {
        await _chatRef(
          scope,
          canonicalChatId,
        ).set(unreadUpdate, SetOptions(merge: true));
      } on Object {
        // Unread counters are secondary metadata; the message itself is saved.
      }
    }
  }

  Future<void> toggleReaction({
    required ChatScope scope,
    required String chatId,
    required String messageId,
    required String emoji,
    required String uid,
    required bool alreadyReacted,
  }) {
    final field = 'reactions.$emoji';
    return _messagesRef(scope, chatId).doc(messageId).update({
      field: alreadyReacted
          ? FieldValue.arrayRemove([uid])
          : FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> deleteMessage({
    required ChatScope scope,
    required String chatId,
    required String messageId,
    required AppUser actor,
  }) async {
    final ref = _messagesRef(scope, chatId).doc(messageId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return;
      final message = ChatMessage.fromSnapshot(snapshot);
      if (!actor.isModerator && actor.uid != message.senderId) {
        throw StateError('Możesz cofnąć tylko własną wiadomość.');
      }
      // When retracting a message, mark it deleted and decrement unread
      // counters for participants who were counted for this message.
      transaction.update(ref, {
        'isDeleted': true,
        'deleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': actor.uid,
        'deletedByName': actor.publicName,
        'originalMessage': message.adminVisibleText,
        'originalTextForAdmin': message.adminVisibleText,
        'originalAttachmentsForAdmin': message.attachments
            .map((attachment) => attachment.toMap())
            .toList(),
        'text': 'Wiadomość cofnięta',
        'imageUrl': null,
        'fileUrl': null,
        'fileName': null,
        'attachments': <Map<String, Object?>>[],
      });
      try {
        final chatRef = _chatRef(message.scope, message.chatId);
        final chatSnapshot = await transaction.get(chatRef);
        final joinedMap = chatSnapshot.data()?['joinedAt'];
        for (final uid in message.participants.where(
          (id) => id != message.senderId,
        )) {
          final joinedTs = joinedMap is Map ? joinedMap[uid] : null;
          DateTime? joinedDate;
          if (joinedTs is Timestamp) joinedDate = joinedTs.toDate();
          if (joinedDate == null) continue;
          if (!message.createdAt.isAfter(joinedDate)) continue;
          transaction.update(chatRef, {
            'unreadCount.$uid': FieldValue.increment(-1),
          });
        }
      } on Object catch (_) {
        // best-effort: if we fail to adjust unread counters, don't block deletion
      }
    });
  }

  Future<void> editMessage({
    required ChatScope scope,
    required String chatId,
    required ChatMessage message,
    required AppUser actor,
    required String newText,
  }) async {
    final cleanText = newText.trim();
    if (cleanText.isEmpty) {
      throw StateError('Wiadomość po edycji nie może być pusta.');
    }
    final canonicalChatId = _canonicalChatId(scope, chatId);
    final ref = _messagesRef(scope, canonicalChatId).doc(message.id);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        throw StateError('Nie znaleziono wiadomości do edycji.');
      }
      final current = ChatMessage.fromSnapshot(snapshot);
      if (current.isDeleted) {
        throw StateError('Nie można edytować cofniętej wiadomości.');
      }
      if (actor.uid != current.senderId && !actor.isAdmin) {
        throw StateError('Możesz edytować tylko własną wiadomość.');
      }
      transaction.update(ref, {
        'text': cleanText,
        'editedAt': FieldValue.serverTimestamp(),
        'editHistory': FieldValue.arrayUnion([
          {
            'oldText': current.text,
            'editedBy': actor.uid,
            'editedByLogin': actor.login,
            'editedAt': Timestamp.fromDate(DateTime.now()),
          },
        ]),
      });
    });
  }

  Future<void> pinMessage({
    required ChatScope scope,
    required String chatId,
    required ChatMessage message,
    required AppUser actor,
  }) async {
    final canonicalChatId = _canonicalChatId(scope, chatId);
    final pinned = PinnedMessage(
      id: message.id,
      messageId: message.id,
      chatId: canonicalChatId,
      chatScope: scope,
      text: message.userVisibleText.isEmpty
          ? 'Załącznik'
          : message.userVisibleText,
      pinnedBy: actor.publicName,
      pinnedAt: DateTime.now(),
    );
    final batch = _firestore.batch();
    batch.update(_messagesRef(scope, canonicalChatId).doc(message.id), {
      'pinned': true,
    });
    batch.set(
      _firestore
          .collection(FirestoreCollections.pinnedMessages)
          .doc(message.id),
      pinned.toMap(),
    );
    await batch.commit();
  }

  Future<void> reportMessage({
    required ChatScope scope,
    required String chatId,
    required ChatMessage message,
    required String reporterId,
    required ReportReason reason,
    String details = '',
  }) async {
    final reportId = _uuid.v4();
    final report = ReportModel(
      id: reportId,
      reporterId: reporterId,
      reason: reason,
      createdAt: DateTime.now(),
      targetMessageId: message.id,
      targetUserId: message.senderId,
      details: details,
    );
    final batch = _firestore.batch();
    batch.set(
      _firestore.collection(FirestoreCollections.reports).doc(reportId),
      report.toMap(),
    );
    batch.update(_messagesRef(scope, chatId).doc(message.id), {
      'reportCount': FieldValue.increment(1),
    });
    await batch.commit();
  }

  Future<void> setTyping({
    required ChatScope scope,
    required String chatId,
    required AppUser user,
    required bool typing,
  }) async {
    final canonicalChatId = _canonicalChatId(scope, chatId);
    final chatRef = _chatRef(scope, canonicalChatId);
    final snapshot = await chatRef.get();
    if (!snapshot.exists) {
      await chatRef.set(
        _chatShellMetadata(
          scope: scope,
          chatId: canonicalChatId,
          actor: user,
          participants: await _participantsFor(
            scope: scope,
            chatId: canonicalChatId,
          ),
        ),
        SetOptions(merge: true),
      );
    }
    return chatRef.collection('typing').doc(user.uid).set({
      'uid': user.uid,
      'displayName': user.publicName,
      'typing': typing,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<TypingUser>> watchTyping({
    required ChatScope scope,
    required String chatId,
    required String currentUserId,
  }) {
    return _chatRef(scope, chatId).collection('typing').snapshots().map((
      snapshot,
    ) {
      final now = DateTime.now();
      return snapshot.docs
          .where((doc) {
            final data = doc.data();
            if (doc.id == currentUserId || data['typing'] != true) {
              return false;
            }
            final updatedAt = data['updatedAt'];
            if (updatedAt is! Timestamp) return true;
            return now.difference(updatedAt.toDate()).inSeconds < 12;
          })
          .map(TypingUser.fromSnapshot)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    });
  }

  Stream<List<ChatMessage>> watchDeletedMessages() {
    return _firestore.collectionGroup('messages').limit(300).snapshots().map((
      snapshot,
    ) {
      final messages =
          snapshot.docs
              .map(ChatMessage.fromSnapshot)
              .where(
                (message) => message.isDeleted || message.deletedAt != null,
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return messages;
    });
  }

  Future<List<String>> _participantsFor({
    required ChatScope scope,
    required String chatId,
  }) async {
    if (scope == ChatScope.private || scope == ChatScope.group) {
      final chat = await _chats.doc(chatId).get();
      final data = chat.data();
      return _stringList(data?['participants'] ?? data?['participantIds']);
    }
    return const [];
  }

  Map<String, Object?> _chatMetadata({
    required ChatScope scope,
    required String chatId,
    required AppUser actor,
    required List<String> participants,
    required String lastMessage,
  }) {
    final base = <String, Object?>{
      'id': chatId,
      'type': scope.wireName,
      'chatKind': scope.wireName,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': lastMessage,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'isArchived': false,
    };

    if (scope == ChatScope.global) {
      return {
        ...base,
        'name': 'Czat główny',
        'participants': <String>[],
        'participantIds': <String>[],
        'participantsMode': 'allActiveUsers',
        'createdBy': 'system',
      };
    }

    if (scope == ChatScope.unit) {
      final unitId = _unitSlug(chatId);
      final serviceName = _serviceChannelName(unitId);
      final actorUnitName = actor.unitName.trim();
      final useActorUnitName =
          actorUnitName.isNotEmpty &&
          TextUtils.normalizeId(actorUnitName) == unitId;
      final unitName =
          serviceName ??
          (useActorUnitName ? actorUnitName : _prettyUnitName(unitId));
      return {
        ...base,
        'name': unitName,
        'unitName': unitName,
        'unitId': unitId,
        'participants': <String>[],
        'participantIds': <String>[],
        'participantsMode': 'unitMembers',
        'createdBy': 'system',
      };
    }

    return {
      ...base,
      'participants': participants,
      'participantIds': participants,
    };
  }

  Map<String, Object?> _messageChatUpdate({
    required ChatScope scope,
    required String chatId,
    required AppUser actor,
    required List<String> participants,
    required String lastMessage,
  }) {
    if (scope == ChatScope.private || scope == ChatScope.group) {
      return {
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': lastMessage,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'hiddenFor': FieldValue.arrayRemove(participants),
      };
    }
    return _chatMetadata(
      scope: scope,
      chatId: chatId,
      actor: actor,
      participants: participants,
      lastMessage: lastMessage,
    );
  }

  Map<String, Object?> _chatShellMetadata({
    required ChatScope scope,
    required String chatId,
    required AppUser actor,
    required List<String> participants,
  }) {
    final base = <String, Object?>{
      'id': chatId,
      'type': scope.wireName,
      'chatKind': scope.wireName,
      'updatedAt': FieldValue.serverTimestamp(),
      'isArchived': false,
    };

    if (scope == ChatScope.global) {
      return {
        ...base,
        'name': 'Czat główny',
        'participants': <String>[],
        'participantIds': <String>[],
        'participantsMode': 'allActiveUsers',
        'createdBy': 'system',
      };
    }

    if (scope == ChatScope.unit) {
      final unitId = _unitSlug(chatId);
      final serviceName = _serviceChannelName(unitId);
      final actorUnitName = actor.unitName.trim();
      final useActorUnitName =
          actorUnitName.isNotEmpty &&
          TextUtils.normalizeId(actorUnitName) == unitId;
      final unitName =
          serviceName ??
          (useActorUnitName ? actorUnitName : _prettyUnitName(unitId));
      return {
        ...base,
        'name': unitName,
        'unitName': unitName,
        'unitId': unitId,
        'participants': <String>[],
        'participantIds': <String>[],
        'participantsMode': 'unitMembers',
        'createdBy': 'system',
      };
    }

    return {
      ...base,
      'participants': participants,
      'participantIds': participants,
    };
  }

  String _canonicalChatId(ChatScope scope, String chatId) {
    if (scope == ChatScope.global) return AppConstants.globalChatId;
    if (scope == ChatScope.unit) return TextUtils.unitChatId(chatId);
    return chatId;
  }

  String _unitSlug(String chatId) {
    final clean = chatId.replaceFirst(RegExp('^unit[_-]'), '').trim();
    if (_serviceChannelName(clean) != null) return clean;
    return TextUtils.normalizeId(clean);
  }

  String _prettyUnitName(String unitId) {
    return unitId
        .split('-')
        .where((part) => part.isNotEmpty)
        .map((part) => part.length <= 3 ? part.toUpperCase() : _titleCase(part))
        .join(' ');
  }

  String? _serviceChannelName(String unitId) {
    return switch (unitId) {
      'service_psp' => 'PSP',
      'service-psp' => 'PSP',
      'service_policja' => 'Policja',
      'service-policja' => 'Policja',
      'service_medycy' => 'Medycy',
      'service-medycy' => 'Medycy',
      'service_media' => 'Media',
      'service-media' => 'Media',
      _ => null,
    };
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  String _contentTypeForFile(
    PlatformFile file, {
    String fallback = 'application/octet-stream',
  }) {
    final extension = (file.extension ?? '').toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'm4a' => 'audio/mp4',
      'mp3' => 'audio/mpeg',
      'wav' => 'audio/wav',
      'aac' => 'audio/aac',
      'ogg' => 'audio/ogg',
      'pdf' => 'application/pdf',
      'txt' => 'text/plain',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => fallback,
    };
  }

  bool _isImageFile(PlatformFile file) {
    final contentType = _contentTypeForFile(file);
    return contentType == 'image/jpeg' ||
        contentType == 'image/png' ||
        contentType == 'image/webp';
  }

  bool _isAudioFile(PlatformFile file) {
    final contentType = _contentTypeForFile(file);
    return contentType == 'audio/mp4' ||
        contentType == 'audio/mpeg' ||
        contentType == 'audio/wav' ||
        contentType == 'audio/aac' ||
        contentType == 'audio/ogg';
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
