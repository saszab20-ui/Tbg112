import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/utils/date_time_utils.dart';
import 'package:tarnobrzeg112/utils/text_utils.dart';

class MessageAttachment {
  const MessageAttachment({
    required this.url,
    required this.mediaType,
    this.fileName,
    this.contentType,
    this.sizeBytes,
  });

  final String url;
  final ChatMediaType mediaType;
  final String? fileName;
  final String? contentType;
  final int? sizeBytes;

  Map<String, Object?> toMap() {
    return {
      'url': url,
      'mediaType': mediaType.name,
      'fileName': fileName,
      'contentType': contentType,
      'sizeBytes': sizeBytes,
    };
  }

  factory MessageAttachment.fromMap(Object? value) {
    final map = value is Map
        ? Map<String, Object?>.from(value)
        : <String, Object?>{};
    final url = _string(map['url']);
    final fileName = _nullableText(map['fileName']);
    final contentType = _nullableString(map['contentType']);
    return MessageAttachment(
      url: url,
      mediaType: _mediaTypeFromValues(
        mediaType: _nullableString(map['mediaType']),
        contentType: contentType,
        fileName: fileName ?? url,
      ),
      fileName: fileName,
      contentType: contentType,
      sizeBytes: _intOrNull(map['sizeBytes']),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.scope,
    required this.senderId,
    required this.senderLogin,
    required this.senderDisplayName,
    required this.senderUnitName,
    required this.createdAt,
    this.senderAvatarUrl,
    this.text = '',
    this.imageUrl,
    this.fileUrl,
    this.fileName,
    this.attachments = const [],
    this.mediaType = ChatMediaType.text,
    this.replyToMessageId,
    this.replyPreview,
    this.editedAt,
    this.deletedAt,
    this.deletedBy,
    this.deletedByName,
    this.pinned = false,
    this.deleted = false,
    this.originalMessage = '',
    this.originalTextForAdmin = '',
    this.originalAttachmentsForAdmin = const [],
    this.visibleTo = const [],
    this.participants = const [],
    this.mentions = const [],
    this.reactions = const {},
    this.editHistory = const [],
    this.reportCount = 0,
  });

  final String id;
  final String chatId;
  final ChatScope scope;
  final String senderId;
  final String senderLogin;
  final String senderDisplayName;
  final String senderUnitName;
  final String? senderAvatarUrl;
  final String text;
  final String? imageUrl;
  final String? fileUrl;
  final String? fileName;
  final List<MessageAttachment> attachments;
  final ChatMediaType mediaType;
  final String? replyToMessageId;
  final String? replyPreview;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final String? deletedBy;
  final String? deletedByName;
  final bool pinned;
  final bool deleted;
  final String originalMessage;
  final String originalTextForAdmin;
  final List<MessageAttachment> originalAttachmentsForAdmin;
  final List<String> visibleTo;
  final List<String> participants;
  final List<String> mentions;
  final Map<String, List<String>> reactions;
  final List<Map<String, Object?>> editHistory;
  final int reportCount;

  bool get hasAttachment =>
      attachments.isNotEmpty || imageUrl != null || fileUrl != null;
  bool get canRender => !deleted;
  bool get isDeleted => deleted;
  String get userVisibleText =>
      deleted ? TextUtils.repairPolishText('Wiadomość cofnięta') : text;
  String get adminVisibleText {
    if (!deleted) return text;
    if (originalMessage.trim().isNotEmpty) return originalMessage;
    if (originalTextForAdmin.trim().isNotEmpty) return originalTextForAdmin;
    return text;
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'chatId': chatId,
      'scope': scope.name,
      'chatType': scope.wireName,
      'senderId': senderId,
      'senderLogin': senderLogin,
      'senderDisplayName': senderDisplayName,
      'senderUnitName': senderUnitName,
      'senderAvatarUrl': senderAvatarUrl,
      'text': text,
      'imageUrl': imageUrl,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'attachments': attachments
          .map((attachment) => attachment.toMap())
          .toList(),
      'mediaType': mediaType.name,
      'replyToMessageId': replyToMessageId,
      'replyPreview': replyPreview,
      'createdAt': Timestamp.fromDate(createdAt),
      'editedAt': editedAt == null ? null : Timestamp.fromDate(editedAt!),
      'deletedAt': deletedAt == null ? null : Timestamp.fromDate(deletedAt!),
      'deletedBy': deletedBy,
      'deletedByName': deletedByName,
      'pinned': pinned,
      'deleted': deleted,
      'isDeleted': deleted,
      'originalMessage': originalMessage,
      'originalTextForAdmin': originalTextForAdmin,
      'originalAttachmentsForAdmin': originalAttachmentsForAdmin
          .map((attachment) => attachment.toMap())
          .toList(),
      'visibleTo': visibleTo,
      'participants': participants,
      'mentions': mentions,
      'reactions': reactions,
      'editHistory': editHistory,
      'reportCount': reportCount,
    };
  }

  factory ChatMessage.fromMap(
    Map<String, Object?> map, {
    required String fallbackId,
  }) {
    final attachments = _attachmentsFromMap(map['attachments']);
    final imageUrl = _nullableString(map['imageUrl']);
    final fileUrl = _nullableString(map['fileUrl']);
    final fileName = _nullableString(map['fileName']);
    return ChatMessage(
      id: _string(map['id'], fallback: fallbackId),
      chatId: _string(map['chatId']),
      scope: ChatScope.fromWire(
        _nullableString(map['scope']) ?? _nullableString(map['chatType']),
      ),
      senderId: _string(map['senderId']),
      senderLogin: _text(map['senderLogin']),
      senderDisplayName: _text(map['senderDisplayName']),
      senderUnitName: _text(map['senderUnitName']),
      senderAvatarUrl: _nullableString(map['senderAvatarUrl']),
      text: _text(map['text']),
      imageUrl: imageUrl,
      fileUrl: fileUrl,
      fileName: fileName == null ? null : TextUtils.repairPolishText(fileName),
      attachments: attachments,
      mediaType: _mediaTypeFromValues(
        mediaType: _nullableString(map['mediaType']),
        contentType: attachments.isEmpty ? null : attachments.first.contentType,
        fileName: fileName ?? imageUrl ?? fileUrl,
      ),
      replyToMessageId: _nullableString(map['replyToMessageId']),
      replyPreview: _nullableText(map['replyPreview']),
      createdAt: DateTimeUtils.fromJson(map['createdAt']) ?? DateTime.now(),
      editedAt: DateTimeUtils.fromJson(map['editedAt']),
      deletedAt: DateTimeUtils.fromJson(map['deletedAt']),
      deletedBy:
          _nullableString(map['deletedByName']) ??
          _nullableString(map['deletedBy']),
      deletedByName: _nullableText(map['deletedByName']),
      pinned: _bool(map['pinned']),
      deleted: _bool(map['isDeleted']) || _bool(map['deleted']),
      originalMessage: _text(map['originalMessage']),
      originalTextForAdmin: _text(map['originalTextForAdmin']),
      originalAttachmentsForAdmin: _attachmentsFromMap(
        map['originalAttachmentsForAdmin'],
      ),
      visibleTo: _stringList(map['visibleTo']),
      participants: _stringList(map['participants']),
      mentions: _stringList(map['mentions']),
      reactions: _reactionsFromMap(map['reactions']),
      editHistory: _editHistoryFromMap(map['editHistory']),
      reportCount: _int(map['reportCount']),
    );
  }

  factory ChatMessage.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      return ChatMessage.fromMap(doc.data() ?? {}, fallbackId: doc.id);
    } on Object catch (error, stackTrace) {
      debugPrint('CHAT MODEL parse error doc=${doc.reference.path}: $error');
      debugPrintStack(stackTrace: stackTrace);
      return ChatMessage(
        id: doc.id,
        chatId: '',
        scope: ChatScope.global,
        senderId: '',
        senderLogin: '',
        senderDisplayName: 'Nieznany użytkownik',
        senderUnitName: '',
        text: '',
        createdAt: DateTime.now(),
        deleted: true,
        originalTextForAdmin: 'Nie udało się odczytać uszkodzonej wiadomości.',
      );
    }
  }

  static Map<String, List<String>> _reactionsFromMap(Object? value) {
    if (value is! Map) return const {};
    return value.map(
      (key, users) => MapEntry(key.toString(), _stringList(users)),
    );
  }

  static List<MessageAttachment> _attachmentsFromMap(Object? value) {
    final items = value is List
        ? value
        : value is Map
        ? [value]
        : const [];
    return items
        .map(MessageAttachment.fromMap)
        .where((attachment) => attachment.url.isNotEmpty)
        .toList();
  }

  static List<Map<String, Object?>> _editHistoryFromMap(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((entry) => Map<String, Object?>.from(entry))
        .toList();
  }
}

String _string(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  if (value is String) return value;
  return value.toString();
}

String _text(Object? value, {String fallback = ''}) {
  return TextUtils.repairPolishText(_string(value, fallback: fallback));
}

String? _nullableString(Object? value) {
  final text = _string(value).trim();
  return text.isEmpty ? null : text;
}

String? _nullableText(Object? value) {
  final text = _text(value).trim();
  return text.isEmpty ? null : text;
}

bool _bool(Object? value) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  return false;
}

int _int(Object? value, {int fallback = 0}) {
  return _intOrNull(value) ?? fallback;
}

int? _intOrNull(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
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

ChatMediaType _mediaTypeFromValues({
  required String? mediaType,
  required String? contentType,
  required String? fileName,
}) {
  final wire = mediaType?.trim().toLowerCase();
  if (wire != null && wire.isNotEmpty && wire != 'text' && wire != 'file') {
    final parsed = ChatMediaType.fromWire(wire);
    if (parsed != ChatMediaType.text) return parsed;
  }

  final mime = contentType?.trim().toLowerCase() ?? '';
  final name = fileName?.trim().toLowerCase() ?? '';
  if (mime.startsWith('image/') ||
      name.endsWith('.jpg') ||
      name.endsWith('.jpeg') ||
      name.endsWith('.png') ||
      name.endsWith('.webp')) {
    return ChatMediaType.image;
  }
  if (mime.startsWith('video/') ||
      name.endsWith('.mp4') ||
      name.endsWith('.mov')) {
    return ChatMediaType.video;
  }
  if (mime.startsWith('audio/') ||
      name.endsWith('.m4a') ||
      name.endsWith('.mp3') ||
      name.endsWith('.wav') ||
      name.endsWith('.aac') ||
      name.endsWith('.ogg')) {
    return ChatMediaType.voice;
  }
  return ChatMediaType.fromWire(wire);
}
