import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tarnobrzeg112/utils/date_time_utils.dart';

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
      id: (map['id'] as String?) ?? fallbackId,
      chatId: (map['chatId'] as String?) ?? '',
      senderId: (map['senderId'] as String?) ?? '',
      senderDisplayName: (map['senderDisplayName'] as String?) ?? '',
      createdAt: DateTimeUtils.fromJson(map['createdAt']) ?? DateTime.now(),
      text: (map['text'] as String?) ?? '',
      imageUrl: map['imageUrl'] as String?,
      readBy: List<String>.from((map['readBy'] as List?) ?? const []),
      reactions: _reactionsFromMap(map['reactions']),
      deleted: (map['deleted'] as bool?) ?? false,
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
      (key, users) => MapEntry(
        key.toString(),
        List<String>.from((users as List?) ?? const []),
      ),
    );
  }
}
