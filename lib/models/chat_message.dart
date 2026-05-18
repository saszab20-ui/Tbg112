import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/utils/date_time_utils.dart';

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
    return MessageAttachment(
      url: (map['url'] as String?) ?? '',
      mediaType: ChatMediaType.fromWire(map['mediaType'] as String?),
      fileName: map['fileName'] as String?,
      contentType: map['contentType'] as String?,
      sizeBytes: (map['sizeBytes'] as num?)?.toInt(),
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
    this.pinned = false,
    this.deleted = false,
    this.originalTextForAdmin = '',
    this.originalAttachmentsForAdmin = const [],
    this.visibleTo = const [],
    this.participants = const [],
    this.reactions = const {},
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
  final bool pinned;
  final bool deleted;
  final String originalTextForAdmin;
  final List<MessageAttachment> originalAttachmentsForAdmin;
  final List<String> visibleTo;
  final List<String> participants;
  final Map<String, List<String>> reactions;
  final int reportCount;

  bool get hasAttachment =>
      attachments.isNotEmpty || imageUrl != null || fileUrl != null;
  bool get canRender => !deleted;
  bool get isDeleted => deleted;
  String get userVisibleText => deleted ? 'Wiadomość cofnięta' : text;
  String get adminVisibleText {
    if (!deleted) return text;
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
      'pinned': pinned,
      'deleted': deleted,
      'isDeleted': deleted,
      'originalTextForAdmin': originalTextForAdmin,
      'originalAttachmentsForAdmin': originalAttachmentsForAdmin
          .map((attachment) => attachment.toMap())
          .toList(),
      'visibleTo': visibleTo,
      'participants': participants,
      'reactions': reactions,
      'reportCount': reportCount,
    };
  }

  factory ChatMessage.fromMap(
    Map<String, Object?> map, {
    required String fallbackId,
  }) {
    return ChatMessage(
      id: (map['id'] as String?) ?? fallbackId,
      chatId: (map['chatId'] as String?) ?? '',
      scope: ChatScope.fromWire(
        (map['scope'] as String?) ?? (map['chatType'] as String?),
      ),
      senderId: (map['senderId'] as String?) ?? '',
      senderLogin: (map['senderLogin'] as String?) ?? '',
      senderDisplayName: (map['senderDisplayName'] as String?) ?? '',
      senderUnitName: (map['senderUnitName'] as String?) ?? '',
      senderAvatarUrl: map['senderAvatarUrl'] as String?,
      text: (map['text'] as String?) ?? '',
      imageUrl: map['imageUrl'] as String?,
      fileUrl: map['fileUrl'] as String?,
      fileName: map['fileName'] as String?,
      attachments: _attachmentsFromMap(map['attachments']),
      mediaType: ChatMediaType.fromWire(map['mediaType'] as String?),
      replyToMessageId: map['replyToMessageId'] as String?,
      replyPreview: map['replyPreview'] as String?,
      createdAt: DateTimeUtils.fromJson(map['createdAt']) ?? DateTime.now(),
      editedAt: DateTimeUtils.fromJson(map['editedAt']),
      deletedAt: DateTimeUtils.fromJson(map['deletedAt']),
      deletedBy: map['deletedBy'] as String?,
      pinned: (map['pinned'] as bool?) ?? false,
      deleted:
          (map['isDeleted'] as bool?) ?? (map['deleted'] as bool?) ?? false,
      originalTextForAdmin: (map['originalTextForAdmin'] as String?) ?? '',
      originalAttachmentsForAdmin: _attachmentsFromMap(
        map['originalAttachmentsForAdmin'],
      ),
      visibleTo: List<String>.from((map['visibleTo'] as List?) ?? const []),
      participants: List<String>.from(
        (map['participants'] as List?) ?? const [],
      ),
      reactions: _reactionsFromMap(map['reactions']),
      reportCount: (map['reportCount'] as num?)?.toInt() ?? 0,
    );
  }

  factory ChatMessage.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    return ChatMessage.fromMap(doc.data() ?? {}, fallbackId: doc.id);
  }

  static Map<String, List<String>> _reactionsFromMap(Object? value) {
    if (value is! Map) return const {};
    return value.map(
      (key, users) => MapEntry(
        key.toString(),
        List<String>.from((users as List?) ?? const []),
      ),
    );
  }

  static List<MessageAttachment> _attachmentsFromMap(Object? value) {
    if (value is! List) return const [];
    return value
        .map(MessageAttachment.fromMap)
        .where((attachment) => attachment.url.isNotEmpty)
        .toList();
  }
}
