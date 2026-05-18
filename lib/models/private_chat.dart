import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tarnobrzeg112/utils/date_time_utils.dart';

class PrivateChat {
  const PrivateChat({
    required this.id,
    required this.participantIds,
    required this.participantNames,
    required this.updatedAt,
    this.chatKind = 'private',
    this.name = '',
    this.ownerId = '',
    this.createdAt,
    this.lastMessage = '',
    this.lastMessageAt,
    this.unreadCount = const {},
    this.typing = const {},
    this.inviteCode,
    this.inviteLink,
    this.isArchived = false,
    this.themeColor = '',
    this.backgroundType = 'preset',
    this.backgroundImageUrl = '',
    this.backgroundPreset = 'default',
  });

  final String id;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final DateTime updatedAt;
  final String chatKind;
  final String name;
  final String ownerId;
  final DateTime? createdAt;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final Map<String, int> unreadCount;
  final Map<String, bool> typing;
  final String? inviteCode;
  final String? inviteLink;
  final bool isArchived;
  final String themeColor;
  final String backgroundType;
  final String backgroundImageUrl;
  final String backgroundPreset;

  bool get isGroup => chatKind == 'group';

  String displayNameFor(String currentUid) {
    if (isGroup) return name.isEmpty ? 'Czat grupowy' : name;
    final other = participantIds.firstWhere(
      (id) => id != currentUid,
      orElse: () => currentUid,
    );
    return participantNames[other] ?? 'Rozmowa prywatna';
  }

  Map<String, Object?> toMap() {
    final namesList = participantIds
        .map((uid) => participantNames[uid] ?? uid)
        .toList();
    return {
      'id': id,
      'type': chatKind,
      'chatKind': chatKind,
      'name': name,
      'createdBy': ownerId,
      'ownerId': ownerId,
      'participants': participantIds,
      'participantIds': participantIds,
      'participantNames': namesList,
      'participantNameMap': participantNames,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt == null
          ? null
          : Timestamp.fromDate(lastMessageAt!),
      'unreadCount': unreadCount,
      'typing': typing,
      'inviteCode': inviteCode,
      'inviteLink': inviteLink,
      'isArchived': isArchived,
      'themeColor': themeColor,
      'backgroundType': backgroundType,
      'backgroundImageUrl': backgroundImageUrl,
      'backgroundPreset': backgroundPreset,
    };
  }

  factory PrivateChat.fromMap(Map<String, Object?> map, {String? fallbackId}) {
    final participantIds = List<String>.from(
      (map['participants'] as List?) ??
          (map['participantIds'] as List?) ??
          const [],
    );
    return PrivateChat(
      id: (map['id'] as String?) ?? fallbackId ?? '',
      participantIds: participantIds,
      participantNames: _participantNames(map, participantIds),
      updatedAt: DateTimeUtils.fromJson(map['updatedAt']) ?? DateTime.now(),
      chatKind:
          (map['type'] as String?) ?? (map['chatKind'] as String?) ?? 'private',
      name: (map['name'] as String?) ?? '',
      ownerId:
          (map['createdBy'] as String?) ?? (map['ownerId'] as String?) ?? '',
      createdAt: DateTimeUtils.fromJson(map['createdAt']),
      lastMessage: (map['lastMessage'] as String?) ?? '',
      lastMessageAt: DateTimeUtils.fromJson(map['lastMessageAt']),
      unreadCount: _intMap(map['unreadCount']),
      typing: Map<String, bool>.from((map['typing'] as Map?) ?? const {}),
      inviteCode: map['inviteCode'] as String?,
      inviteLink: map['inviteLink'] as String?,
      isArchived: (map['isArchived'] as bool?) ?? false,
      themeColor: (map['themeColor'] as String?) ?? '',
      backgroundType: (map['backgroundType'] as String?) ?? 'preset',
      backgroundImageUrl: (map['backgroundImageUrl'] as String?) ?? '',
      backgroundPreset: (map['backgroundPreset'] as String?) ?? 'default',
    );
  }

  factory PrivateChat.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    return PrivateChat.fromMap(doc.data() ?? {}, fallbackId: doc.id);
  }

  static Map<String, String> _participantNames(
    Map<String, Object?> map,
    List<String> participantIds,
  ) {
    final nameMap = map['participantNameMap'];
    if (nameMap is Map) return Map<String, String>.from(nameMap);

    final legacy = map['participantNames'];
    if (legacy is Map) return Map<String, String>.from(legacy);
    if (legacy is List) {
      return {
        for (var i = 0; i < participantIds.length && i < legacy.length; i++)
          participantIds[i]: legacy[i].toString(),
      };
    }
    return const {};
  }

  static Map<String, int> _intMap(Object? value) {
    if (value is! Map) return const {};
    return value.map(
      (key, val) => MapEntry(key.toString(), (val as num).toInt()),
    );
  }
}
