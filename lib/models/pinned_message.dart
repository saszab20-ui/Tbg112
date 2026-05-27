import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/utils/date_time_utils.dart';
import 'package:tarnobrzeg112/utils/text_utils.dart';

class PinnedMessage {
  const PinnedMessage({
    required this.id,
    required this.messageId,
    required this.chatId,
    required this.chatScope,
    required this.text,
    required this.pinnedBy,
    required this.pinnedAt,
  });

  final String id;
  final String messageId;
  final String chatId;
  final ChatScope chatScope;
  final String text;
  final String pinnedBy;
  final DateTime pinnedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'messageId': messageId,
      'chatId': chatId,
      'chatScope': chatScope.name,
      'text': text,
      'pinnedBy': pinnedBy,
      'pinnedAt': Timestamp.fromDate(pinnedAt),
    };
  }

  factory PinnedMessage.fromMap(
    Map<String, Object?> map, {
    String? fallbackId,
  }) {
    return PinnedMessage(
      id: (map['id'] as String?) ?? fallbackId ?? '',
      messageId: (map['messageId'] as String?) ?? '',
      chatId: (map['chatId'] as String?) ?? '',
      chatScope: ChatScope.fromWire(map['chatScope'] as String?),
      text: TextUtils.repairPolishText((map['text'] as String?) ?? ''),
      pinnedBy: TextUtils.repairPolishText((map['pinnedBy'] as String?) ?? ''),
      pinnedAt: DateTimeUtils.fromJson(map['pinnedAt']) ?? DateTime.now(),
    );
  }

  factory PinnedMessage.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return PinnedMessage.fromMap(doc.data() ?? {}, fallbackId: doc.id);
  }
}
