import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/utils/date_time_utils.dart';
import 'package:tarnobrzeg112/utils/text_utils.dart';

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.recipientId,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.data = const {},
    this.read = false,
  });

  final String id;
  final String recipientId;
  final String title;
  final String body;
  final NotificationKind type;
  final DateTime createdAt;
  final Map<String, String> data;
  final bool read;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'recipientId': recipientId,
      'title': title,
      'body': body,
      'type': type.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'data': data,
      'read': read,
    };
  }

  factory NotificationModel.fromMap(
    Map<String, Object?> map, {
    String? fallbackId,
  }) {
    return NotificationModel(
      id: (map['id'] as String?) ?? fallbackId ?? '',
      recipientId: (map['recipientId'] as String?) ?? '',
      title: TextUtils.repairPolishText((map['title'] as String?) ?? ''),
      body: TextUtils.repairPolishText((map['body'] as String?) ?? ''),
      type: NotificationKind.fromWire(map['type'] as String?),
      createdAt: DateTimeUtils.fromJson(map['createdAt']) ?? DateTime.now(),
      data: Map<String, String>.from((map['data'] as Map?) ?? const {}),
      read: (map['read'] as bool?) ?? false,
    );
  }

  factory NotificationModel.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return NotificationModel.fromMap(doc.data() ?? {}, fallbackId: doc.id);
  }
}
