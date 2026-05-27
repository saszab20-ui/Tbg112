import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tarnobrzeg112/utils/date_time_utils.dart';
import 'package:tarnobrzeg112/utils/text_utils.dart';

class PrivateMessage {
  const PrivateMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderDisplayName,
    required this.createdAt,
    this.text = '',
    this.imageUrl,
    this.readBy = const [],
    this.reactions = const {},
    this.deleted = false,
  });

  final String id;
  final String chatId;
  final String senderId;
  final String senderDisplayName;
  final DateTime createdAt;
  final String text;
  final String? imageUrl;
  final List<String> readBy;
  final Map<String, List<String>> reactions;
  final bool deleted;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'senderDisplayName': senderDisplayName,
      'createdAt': Timestamp.fromDate(createdAt),
      'text': text,
      'imageUrl': imageUrl,
      'readBy': readBy,
      'reactions': reactions,
      'deleted': deleted,
    };
  }

  factory PrivateMessage.fromMap(
    Map<String, Object?> map, {
    required String fallbackId,
  }) {
    return PrivateMessage(
      id: _string(map['id'], fallback: fallbackId),
      chatId: _string(map['chatId']),
      senderId: _string(map['senderId']),
      senderDisplayName: _text(map['senderDisplayName']),
      createdAt: DateTimeUtils.fromJson(map['createdAt']) ?? DateTime.now(),
      text: _text(map['text']),
      imageUrl: _nullableString(map['imageUrl']),
      readBy: _stringList(map['readBy']),
      reactions: _reactionsFromMap(map['reactions']),
      deleted: _bool(map['deleted']),
    );
  }

  factory PrivateMessage.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return PrivateMessage.fromMap(doc.data() ?? {}, fallbackId: doc.id);
  }

  static Map<String, List<String>> _reactionsFromMap(Object? value) {
    if (value is! Map) return const {};
    return value.map(
      (key, users) => MapEntry(key.toString(), _stringList(users)),
    );
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

bool _bool(Object? value) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  return false;
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
