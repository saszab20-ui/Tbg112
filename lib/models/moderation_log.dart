import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tarnobrzeg112/utils/date_time_utils.dart';
import 'package:tarnobrzeg112/utils/text_utils.dart';

class ModerationLog {
  const ModerationLog({
    required this.id,
    required this.action,
    required this.performedBy,
    required this.performedByLogin,
    required this.createdAt,
    this.targetUserId,
    this.targetUserLogin,
    this.oldValue,
    this.newValue,
    this.targetMessageId,
  });

  final String id;
  final String action;
  final String performedBy;
  final String performedByLogin;
  final DateTime createdAt;
  final String? targetUserId;
  final String? targetUserLogin;
  final String? oldValue;
  final String? newValue;
  final String? targetMessageId;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'action': action,
      'targetUserId': targetUserId,
      'targetUserLogin': targetUserLogin,
      'performedBy': performedBy,
      'performedByLogin': performedByLogin,
      'oldValue': oldValue,
      'newValue': newValue,
      'targetMessageId': targetMessageId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ModerationLog.fromMap(
    Map<String, Object?> map, {
    String? fallbackId,
  }) {
    return ModerationLog(
      id: (map['id'] as String?) ?? fallbackId ?? '',
      action: (map['action'] as String?) ?? '',
      performedBy:
          (map['performedBy'] as String?) ?? (map['actorId'] as String?) ?? '',
      performedByLogin: TextUtils.repairPolishText(
        (map['performedByLogin'] as String?) ??
            (map['actorName'] as String?) ??
            '',
      ),
      createdAt: DateTimeUtils.fromJson(map['createdAt']) ?? DateTime.now(),
      targetUserId: map['targetUserId'] as String?,
      targetUserLogin: _nullableText(map['targetUserLogin']),
      oldValue: _nullableText(map['oldValue']),
      newValue: _nullableText(map['newValue'] ?? map['details']),
      targetMessageId: map['targetMessageId'] as String?,
    );
  }

  factory ModerationLog.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ModerationLog.fromMap(doc.data() ?? {}, fallbackId: doc.id);
  }
}

String? _nullableText(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  return TextUtils.repairPolishText(text);
}
