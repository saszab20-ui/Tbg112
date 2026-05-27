import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tarnobrzeg112/utils/date_time_utils.dart';
import 'package:tarnobrzeg112/utils/text_utils.dart';

class AppSettings {
  const AppSettings({
    required this.id,
    required this.updatedAt,
    this.registrationEnabled = true,
    this.maintenanceMode = false,
    this.minSupportedBuild = 1,
    this.broadcastTitle = '',
    this.broadcastBody = '',
  });

  final String id;
  final bool registrationEnabled;
  final bool maintenanceMode;
  final int minSupportedBuild;
  final String broadcastTitle;
  final String broadcastBody;
  final DateTime updatedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'registrationEnabled': registrationEnabled,
      'maintenanceMode': maintenanceMode,
      'minSupportedBuild': minSupportedBuild,
      'broadcastTitle': broadcastTitle,
      'broadcastBody': broadcastBody,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory AppSettings.fromMap(Map<String, Object?> map, {String? fallbackId}) {
    return AppSettings(
      id: (map['id'] as String?) ?? fallbackId ?? 'main',
      registrationEnabled: (map['registrationEnabled'] as bool?) ?? true,
      maintenanceMode: (map['maintenanceMode'] as bool?) ?? false,
      minSupportedBuild: (map['minSupportedBuild'] as num?)?.toInt() ?? 1,
      broadcastTitle: TextUtils.repairPolishText(
        (map['broadcastTitle'] as String?) ?? '',
      ),
      broadcastBody: TextUtils.repairPolishText(
        (map['broadcastBody'] as String?) ?? '',
      ),
      updatedAt: DateTimeUtils.fromJson(map['updatedAt']) ?? DateTime.now(),
    );
  }

  factory AppSettings.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    return AppSettings.fromMap(doc.data() ?? {}, fallbackId: doc.id);
  }
}
