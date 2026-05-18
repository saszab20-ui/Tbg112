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
      fileUrl = await _storageService.uploadChatFile(
        chatPath: '${scope.wireName}/$canonicalChatId',
        fileName: file.name,
        bytes: bytes,
        contentType: _contentTypeForFile(file),
      );
      mediaType = ChatMediaType.file;
      attachments.add(
        MessageAttachment(
          url: fileUrl,
          mediaType: ChatMediaType.file,
          fileName: file.name,
          contentType: _contentTypeForFile(file),
          sizeBytes: file.size,
        ),
      );
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
      createdAt: DateTime.now(),
      visibleTo: participants,
      participants: participants,
    );

    final batch = _firestore.batch();
    batch.set(
      _chatRef(scope, canonicalChatId),
      _chatMetadata(
        scope: scope,
        chatId: canonicalChatId,
        actor: sender,
        participants: participants,
        lastMessage: text.trim().isEmpty ? mediaType.label : text.trim(),
      ),
      SetOptions(merge: true),
    );
    batch.set(_messagesRef(scope, canonicalChatId).doc(id), message.toMap());
    await batch.commit();
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
      transaction.update(ref, {
        'isDeleted': true,
        'deleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': actor.uid,
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
  }) {
    return _chatRef(scope, chatId).collection('typing').doc(user.uid).set({
      'uid': user.uid,
      'displayName': user.publicName,
      'typing': typing,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<ChatMessage>> watchDeletedMessages() {
    return _firestore
        .collectionGroup('messages')
        .where('isDeleted', isEqualTo: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(ChatMessage.fromSnapshot).toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Future<List<String>> _participantsFor({
    required ChatScope scope,
    required String chatId,
  }) async {
    if (scope == ChatScope.private || scope == ChatScope.group) {
      final chat = await _chats.doc(chatId).get();
      return List<String>.from(
        (chat.data()?['participants'] as List?) ??
            (chat.data()?['participantIds'] as List?) ??
            const [],
      );
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
      final actorUnitName = actor.unitName.trim();
      final useActorUnitName =
          actorUnitName.isNotEmpty &&
          TextUtils.normalizeId(actorUnitName) == unitId;
      final unitName = useActorUnitName
          ? actorUnitName
          : _prettyUnitName(unitId);
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
    return TextUtils.normalizeId(chatId.replaceFirst(RegExp('^unit[_-]'), ''));
  }

  String _prettyUnitName(String unitId) {
    return unitId
        .split('-')
        .where((part) => part.isNotEmpty)
        .map((part) => part.length <= 3 ? part.toUpperCase() : _titleCase(part))
        .join(' ');
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
      'pdf' => 'application/pdf',
      'txt' => 'text/plain',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => fallback,
    };
  }
}
