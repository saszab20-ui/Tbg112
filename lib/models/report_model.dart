import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/utils/date_time_utils.dart';

class ReportModel {
  const ReportModel({
    required this.id,
    required this.reporterId,
    required this.reason,
    required this.createdAt,
    this.targetMessageId,
    this.targetUserId,
    this.details = '',
    this.status = 'open',
    this.resolvedAt,
    this.assignedAdminId,
  });

  final String id;
  final String reporterId;
  final ReportReason reason;
  final DateTime createdAt;
  final String? targetMessageId;
  final String? targetUserId;
  final String details;
  final String status;
  final DateTime? resolvedAt;
  final String? assignedAdminId;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'reporterId': reporterId,
      'reason': reason.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'targetMessageId': targetMessageId,
      'targetUserId': targetUserId,
      'details': details,
      'status': status,
      'resolvedAt': resolvedAt == null ? null : Timestamp.fromDate(resolvedAt!),
      'assignedAdminId': assignedAdminId,
    };
  }

  factory ReportModel.fromMap(Map<String, Object?> map, {String? fallbackId}) {
    return ReportModel(
      id: (map['id'] as String?) ?? fallbackId ?? '',
      reporterId: (map['reporterId'] as String?) ?? '',
      reason: ReportReason.fromWire(map['reason'] as String?),
      createdAt: DateTimeUtils.fromJson(map['createdAt']) ?? DateTime.now(),
      targetMessageId: map['targetMessageId'] as String?,
      targetUserId: map['targetUserId'] as String?,
      details: (map['details'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'open',
      resolvedAt: DateTimeUtils.fromJson(map['resolvedAt']),
      assignedAdminId: map['assignedAdminId'] as String?,
    );
  }

  factory ReportModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    return ReportModel.fromMap(doc.data() ?? {}, fallbackId: doc.id);
  }
}
