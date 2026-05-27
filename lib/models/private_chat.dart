import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tarnobrzeg112/utils/date_time_utils.dart';
import 'package:tarnobrzeg112/utils/text_utils.dart';

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
    this.isArchived = false,
    this.themeColor = '',
    this.messageStyle = 'rounded',
    this.chatTheme = 'default',
    this.backgroundType = 'preset',
    this.backgroundImageUrl = '',
    this.backgroundPreset = 'default',
    this.incomingSound = 'unique_sms',
    this.privateSound = 'cool_sms_tone',
    this.mentionSound = 'alarm',
    this.sendSound = 'classic',
    this.adminAlertSound = 'high_alert',
    this.vibrationEnabled = true,
    this.notificationMode = 'loud',
    this.hiddenFor = const [],
    this.clearedAt = const {},
    this.joinedAt = const {},
    this.deliveredReceipts = const {},
    this.readReceipts = const {},
    this.visibilityMode = 'unlimited',
    this.expiresAt,
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
  final bool isArchived;
  final String themeColor;
  final String messageStyle;
  final String chatTheme;
  final String backgroundType;
  final String backgroundImageUrl;
  final String backgroundPreset;
  final String incomingSound;
  final String privateSound;
  final String mentionSound;
  final String sendSound;
  final String adminAlertSound;
  final bool vibrationEnabled;
  final String notificationMode;
  final List<String> hiddenFor;
  final Map<String, DateTime> clearedAt;
  final Map<String, DateTime> joinedAt;
  final Map<String, DateTime> deliveredReceipts;
  final Map<String, DateTime> readReceipts;
  final String visibilityMode;
  final DateTime? expiresAt;

  bool get isGroup => chatKind == 'group';
  bool get isExpired =>
      visibilityMode == '24h' &&
      expiresAt != null &&
      !expiresAt!.isAfter(DateTime.now());

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
      'isArchived': isArchived,
      'themeColor': themeColor,
      'messageStyle': messageStyle,
      'chatTheme': chatTheme,
      'backgroundType': backgroundType,
      'backgroundImageUrl': backgroundImageUrl,
      'backgroundPreset': backgroundPreset,
      'incomingSound': incomingSound,
      'privateSound': privateSound,
      'mentionSound': mentionSound,
      'sendSound': sendSound,
      'adminAlertSound': adminAlertSound,
      'vibrationEnabled': vibrationEnabled,
      'notificationMode': notificationMode,
      'hiddenFor': hiddenFor,
      'clearedAt': clearedAt.map(
        (uid, value) => MapEntry(uid, Timestamp.fromDate(value)),
      ),
      'joinedAt': joinedAt.map(
        (uid, value) => MapEntry(uid, Timestamp.fromDate(value)),
      ),
      'deliveredReceipts': deliveredReceipts.map(
        (uid, value) => MapEntry(uid, Timestamp.fromDate(value)),
      ),
      'readReceipts': readReceipts.map(
        (uid, value) => MapEntry(uid, Timestamp.fromDate(value)),
      ),
      'visibilityMode': visibilityMode,
      'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt!),
    };
  }

  factory PrivateChat.fromMap(Map<String, Object?> map, {String? fallbackId}) {
    final participantIds = _stringList(
      map['participants'] ?? map['participantIds'],
    );
    return PrivateChat(
      id: _string(map['id'], fallback: fallbackId ?? ''),
      participantIds: participantIds,
      participantNames: _participantNames(map, participantIds),
      updatedAt: DateTimeUtils.fromJson(map['updatedAt']) ?? DateTime.now(),
      chatKind: _string(map['type'] ?? map['chatKind'], fallback: 'private'),
      name: _text(map['name']),
      ownerId: _string(map['createdBy'] ?? map['ownerId']),
      createdAt: DateTimeUtils.fromJson(map['createdAt']),
      lastMessage: _text(map['lastMessage']),
      lastMessageAt: DateTimeUtils.fromJson(map['lastMessageAt']),
      unreadCount: _intMap(map['unreadCount']),
      typing: _boolMap(map['typing']),
      isArchived: _bool(map['isArchived']),
      themeColor: _string(map['themeColor']),
      messageStyle: _string(map['messageStyle'], fallback: 'rounded'),
      chatTheme: _string(map['chatTheme'], fallback: 'default'),
      backgroundType: _string(map['backgroundType'], fallback: 'preset'),
      backgroundImageUrl: _string(map['backgroundImageUrl']),
      backgroundPreset: _string(map['backgroundPreset'], fallback: 'default'),
      incomingSound: _string(map['incomingSound'], fallback: 'unique_sms'),
      privateSound: _string(map['privateSound'], fallback: 'cool_sms_tone'),
      mentionSound: _string(map['mentionSound'], fallback: 'alarm'),
      sendSound: _string(map['sendSound'], fallback: 'classic'),
      adminAlertSound: _string(map['adminAlertSound'], fallback: 'high_alert'),
      vibrationEnabled: _bool(map['vibrationEnabled'], fallback: true),
      notificationMode: _string(map['notificationMode'], fallback: 'loud'),
      hiddenFor: _stringList(map['hiddenFor']),
      clearedAt: _dateMap(map['clearedAt']),
      joinedAt: _dateMap(map['joinedAt']),
      deliveredReceipts: _dateMap(map['deliveredReceipts']),
      readReceipts: _dateMap(map['readReceipts'] ?? map['lastReadAt']),
      visibilityMode: _string(map['visibilityMode'], fallback: 'unlimited'),
      expiresAt: DateTimeUtils.fromJson(map['expiresAt']),
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
    if (nameMap is Map) {
      return nameMap.map(
        (key, value) => MapEntry(
          key.toString(),
          TextUtils.repairPolishText(value?.toString() ?? ''),
        ),
      );
    }

    final legacy = map['participantNames'];
    if (legacy is Map) {
      return legacy.map(
        (key, value) => MapEntry(
          key.toString(),
          TextUtils.repairPolishText(value?.toString() ?? ''),
        ),
      );
    }
    if (legacy is List) {
      return {
        for (var i = 0; i < participantIds.length && i < legacy.length; i++)
          participantIds[i]: TextUtils.repairPolishText(legacy[i].toString()),
      };
    }
    return const {};
  }

  static Map<String, int> _intMap(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, val) => MapEntry(key.toString(), _int(val)));
  }

  static Map<String, bool> _boolMap(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, val) => MapEntry(key.toString(), _bool(val)));
  }

  static Map<String, DateTime> _dateMap(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, val) {
      return MapEntry(
        key.toString(),
        DateTimeUtils.fromJson(val) ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
    });
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

bool _bool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  return fallback;
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
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
