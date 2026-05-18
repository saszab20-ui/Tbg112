import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/utils/date_time_utils.dart';

class UnitModel {
  const UnitModel({
    required this.id,
    required this.name,
    required this.type,
    required this.voivodeship,
    required this.county,
    required this.createdAt,
    this.description = '',
    this.memberIds = const [],
    this.moderatorIds = const [],
    this.active = true,
  });

  final String id;
  final String name;
  final UnitType type;
  final String voivodeship;
  final String county;
  final DateTime createdAt;
  final String description;
  final List<String> memberIds;
  final List<String> moderatorIds;
  final bool active;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'voivodeship': voivodeship,
      'county': county,
      'createdAt': Timestamp.fromDate(createdAt),
      'description': description,
      'memberIds': memberIds,
      'moderatorIds': moderatorIds,
      'active': active,
    };
  }

  factory UnitModel.fromMap(Map<String, Object?> map, {String? fallbackId}) {
    return UnitModel(
      id: (map['id'] as String?) ?? fallbackId ?? '',
      name: (map['name'] as String?) ?? '',
      type: UnitType.fromWire(map['type'] as String?),
      voivodeship: (map['voivodeship'] as String?) ?? '',
      county: (map['county'] as String?) ?? '',
      createdAt: DateTimeUtils.fromJson(map['createdAt']) ?? DateTime.now(),
      description: (map['description'] as String?) ?? '',
      memberIds: List<String>.from((map['memberIds'] as List?) ?? const []),
      moderatorIds: List<String>.from(
        (map['moderatorIds'] as List?) ?? const [],
      ),
      active: (map['active'] as bool?) ?? true,
    );
  }

  factory UnitModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    return UnitModel.fromMap(doc.data() ?? {}, fallbackId: doc.id);
  }
}
