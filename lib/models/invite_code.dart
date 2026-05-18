import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/utils/date_time_utils.dart';

class InviteCode {
  const InviteCode({
    required this.code,
    required this.serviceType,
    required this.unitName,
    required this.active,
    required this.maxUses,
    required this.usedCount,
    required this.createdBy,
    required this.createdAt,
  });

  final String code;
  final UnitType serviceType;
  final String unitName;
  final bool active;
  final int maxUses;
  final int usedCount;
  final String createdBy;
  final DateTime createdAt;

  bool get canUse => active && usedCount < maxUses;

  Map<String, Object?> toMap() {
    return {
      'code': code,
      'serviceType': serviceType.name,
      'unitName': unitName,
      'active': active,
      'maxUses': maxUses,
      'usedCount': usedCount,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory InviteCode.fromMap(Map<String, Object?> map, {String? fallbackCode}) {
    return InviteCode(
      code: (map['code'] as String?) ?? fallbackCode ?? '',
      serviceType: UnitType.fromWire(map['serviceType'] as String?),
      unitName: (map['unitName'] as String?) ?? '',
      active: (map['active'] as bool?) ?? false,
      maxUses: (map['maxUses'] as num?)?.toInt() ?? 1,
      usedCount: (map['usedCount'] as num?)?.toInt() ?? 0,
      createdBy: (map['createdBy'] as String?) ?? '',
      createdAt: DateTimeUtils.fromJson(map['createdAt']) ?? DateTime.now(),
    );
  }

  factory InviteCode.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    return InviteCode.fromMap(doc.data() ?? {}, fallbackCode: doc.id);
  }
}
