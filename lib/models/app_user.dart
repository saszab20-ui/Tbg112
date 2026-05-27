import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/utils/date_time_utils.dart';
import 'package:tarnobrzeg112/utils/text_utils.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.login,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.nickname,
    required this.phoneNumber,
    required this.unitType,
    required this.unitId,
    required this.unitName,
    required this.voivodeship,
    required this.county,
    required this.role,
    required this.accountStatus,
    required this.presenceStatus,
    required this.joinedAt,
    required this.lastSeenAt,
    this.customStatus = '',
    this.avatarUrl,
    this.description = '',
    this.mutedUntil,
    this.muted = false,
    this.mutedReason = '',
    this.mutedBy = '',
    this.moderatorPermissions = const {},
    this.adminNotes = '',
    this.requestedUnitType = '',
    this.requestedUnitName = '',
    this.blockedWrite = false,
    this.trustedAdminCandidate = false,
    this.mustChangePassword = false,
    this.firstLoginTutorialCompleted = true,
    this.fcmTokens = const [],
  });

  final String uid;
  final String login;
  final String email;
  final String firstName;
  final String lastName;
  final String nickname;
  final String phoneNumber;
  final UnitType unitType;
  final String unitId;
  final String unitName;
  final String voivodeship;
  final String county;
  final UserRole role;
  final AccountStatus accountStatus;
  final PresenceStatus presenceStatus;
  final DateTime joinedAt;
  final DateTime? lastSeenAt;
  final String customStatus;
  final String? avatarUrl;
  final String description;
  final DateTime? mutedUntil;
  final bool muted;
  final String mutedReason;
  final String mutedBy;
  final Map<String, bool> moderatorPermissions;
  final String adminNotes;
  final String requestedUnitType;
  final String requestedUnitName;
  final bool blockedWrite;
  final bool trustedAdminCandidate;
  final bool mustChangePassword;
  final bool firstLoginTutorialCompleted;
  final List<String> fcmTokens;

  String get preferredChatName {
    final cleanNickname = nickname.trim();
    if (cleanNickname.isNotEmpty) return cleanNickname;
    final cleanFirstName = firstName.trim();
    if (cleanFirstName.isNotEmpty) {
      return cleanFirstName.split(RegExp(r'\s+')).first;
    }
    final cleanFullName = fullName.trim();
    if (cleanFullName.isNotEmpty) {
      return cleanFullName.split(RegExp(r'\s+')).first;
    }
    return login;
  }

  String get publicName {
    final cleanNickname = preferredChatName;
    final cleanUnit = unitName.trim();
    if (cleanUnit.isEmpty &&
        (unitType == UnitType.media || unitType == UnitType.informator)) {
      return '$cleanNickname (${unitType.label})';
    }
    if (cleanUnit.isEmpty) return cleanNickname;
    return '$cleanNickname ($cleanUnit)';
  }

  String get fullName => [
    firstName,
    lastName,
  ].map((part) => part.trim()).where((part) => part.isNotEmpty).join(' ');
  bool get hasFullName =>
      firstName.trim().isNotEmpty && lastName.trim().isNotEmpty;
  String get firstNameForHome {
    final cleanFirstName = firstName.trim();
    if (cleanFirstName.isNotEmpty) {
      return cleanFirstName.split(RegExp(r'\s+')).first;
    }
    return displayName;
  }

  String get phoneNumberOrDash =>
      phoneNumber.trim().isEmpty ? '-' : phoneNumber;
  String get initials => TextUtils.initials(displayName);
  bool get isActive => accountStatus == AccountStatus.active;
  bool get isAdmin => role == UserRole.admin;
  bool get isModerator => role == UserRole.moderator || role == UserRole.admin;
  bool get isMuted =>
      muted || (mutedUntil != null && mutedUntil!.isAfter(DateTime.now()));
  bool get canWrite => isActive && !blockedWrite && !isMuted;
  bool get isTrustedAdminCandidate => trustedAdminCandidate;
  bool get hasUnitChatAccess =>
      unitType.hasOwnUnitChat && unitName.trim().isNotEmpty;
  bool moderatorCan(String key) => isAdmin || moderatorPermissions[key] == true;
  String get displayName {
    final cleanNickname = nickname.trim();
    if (cleanNickname.isNotEmpty) return cleanNickname;
    final cleanFullName = fullName.trim();
    if (cleanFullName.isNotEmpty) return cleanFullName;
    return login;
  }

  AppUser copyWith({
    String? uid,
    String? login,
    String? email,
    String? firstName,
    String? lastName,
    String? nickname,
    String? phoneNumber,
    UnitType? unitType,
    String? unitId,
    String? unitName,
    String? voivodeship,
    String? county,
    UserRole? role,
    AccountStatus? accountStatus,
    PresenceStatus? presenceStatus,
    DateTime? joinedAt,
    DateTime? lastSeenAt,
    String? customStatus,
    String? avatarUrl,
    String? description,
    DateTime? mutedUntil,
    bool? muted,
    String? mutedReason,
    String? mutedBy,
    Map<String, bool>? moderatorPermissions,
    String? adminNotes,
    String? requestedUnitType,
    String? requestedUnitName,
    bool? blockedWrite,
    bool? trustedAdminCandidate,
    bool? mustChangePassword,
    bool? firstLoginTutorialCompleted,
    List<String>? fcmTokens,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      login: login ?? this.login,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      nickname: nickname ?? this.nickname,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      unitType: unitType ?? this.unitType,
      unitId: unitId ?? this.unitId,
      unitName: unitName ?? this.unitName,
      voivodeship: voivodeship ?? this.voivodeship,
      county: county ?? this.county,
      role: role ?? this.role,
      accountStatus: accountStatus ?? this.accountStatus,
      presenceStatus: presenceStatus ?? this.presenceStatus,
      joinedAt: joinedAt ?? this.joinedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      customStatus: customStatus ?? this.customStatus,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      description: description ?? this.description,
      mutedUntil: mutedUntil ?? this.mutedUntil,
      muted: muted ?? this.muted,
      mutedReason: mutedReason ?? this.mutedReason,
      mutedBy: mutedBy ?? this.mutedBy,
      moderatorPermissions: moderatorPermissions ?? this.moderatorPermissions,
      adminNotes: adminNotes ?? this.adminNotes,
      requestedUnitType: requestedUnitType ?? this.requestedUnitType,
      requestedUnitName: requestedUnitName ?? this.requestedUnitName,
      blockedWrite: blockedWrite ?? this.blockedWrite,
      trustedAdminCandidate:
          trustedAdminCandidate ?? this.trustedAdminCandidate,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      firstLoginTutorialCompleted:
          firstLoginTutorialCompleted ?? this.firstLoginTutorialCompleted,
      fcmTokens: fcmTokens ?? this.fcmTokens,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'uid': uid,
      'login': login,
      'email': email,
      'authEmail': email,
      'firstName': firstName,
      'lastName': lastName,
      'fullName': fullName,
      'nickname': nickname,
      'phoneNumber': phoneNumber,
      'phone': phoneNumber,
      'unitType': unitType.name,
      'serviceType': unitType.badgeLabel,
      'unitId': unitId,
      'unitName': unitName,
      'voivodeship': voivodeship,
      'county': county,
      'role': role.name,
      'accountStatus': accountStatus.name,
      'presenceStatus': presenceStatus.name,
      'customStatus': customStatus,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'createdAt': Timestamp.fromDate(joinedAt),
      'lastSeenAt': lastSeenAt == null ? null : Timestamp.fromDate(lastSeenAt!),
      'avatarUrl': avatarUrl,
      'description': description,
      'mutedUntil': mutedUntil == null ? null : Timestamp.fromDate(mutedUntil!),
      'muted': muted,
      'mutedReason': mutedReason,
      'mutedBy': mutedBy,
      'moderatorPermissions': moderatorPermissions,
      'adminNotes': adminNotes,
      'requestedUnitType': requestedUnitType,
      'requestedUnitName': requestedUnitName,
      'blockedWrite': blockedWrite,
      'canWrite': canWrite,
      'trustedAdminCandidate': trustedAdminCandidate,
      'mustChangePassword': mustChangePassword,
      'mustSetPassword': mustChangePassword,
      'firstLoginTutorialCompleted': firstLoginTutorialCompleted,
      'fcmTokens': fcmTokens,
      'displayName': displayName,
      'publicName': publicName,
      'searchIndex': [
        email.toLowerCase(),
        login.toLowerCase(),
        firstName.toLowerCase(),
        lastName.toLowerCase(),
        nickname.toLowerCase(),
        unitName.toLowerCase(),
      ],
    };
  }

  factory AppUser.fromMap(Map<String, Object?> map, {String? fallbackUid}) {
    final unitName = _text(map['unitName']);
    final email =
        _nullableString(map['authEmail']) ??
        _nullableString(map['email']) ??
        '';
    final login = _nullableString(map['login']) ?? email.split('@').first;
    final serviceType = _nullableString(map['serviceType']);
    final unitTypeRaw = _nullableString(map['unitType']);
    final fullNameParts = _splitFullName(_text(map['fullName']));
    final firstName =
        _nullableText(map['firstName']) ??
        (fullNameParts.isEmpty ? '' : fullNameParts.first);
    final lastName =
        _nullableText(map['lastName']) ??
        (fullNameParts.length < 2 ? '' : fullNameParts.last);
    return AppUser(
      uid: _string(map['uid'], fallback: fallbackUid ?? ''),
      login: login,
      email: email,
      firstName: firstName,
      lastName: lastName,
      nickname: _text(map['nickname']),
      phoneNumber: _string(map['phoneNumber'] ?? map['phone']),
      unitType: UnitType.fromWire(serviceType ?? unitTypeRaw),
      unitId: _nullableString(map['unitId']) ?? TextUtils.normalizeId(unitName),
      unitName: unitName,
      voivodeship: _text(map['voivodeship']),
      county: _text(map['county']),
      role: UserRole.fromWire(_nullableString(map['role'])),
      accountStatus: AccountStatus.fromWire(
        _nullableString(map['accountStatus']),
      ),
      presenceStatus: PresenceStatus.fromWire(
        _nullableString(map['presenceStatus']),
      ),
      joinedAt:
          DateTimeUtils.fromJson(map['joinedAt']) ??
          DateTimeUtils.fromJson(map['createdAt']) ??
          DateTime.now(),
      lastSeenAt: DateTimeUtils.fromJson(map['lastSeenAt']),
      customStatus: _string(map['customStatus']),
      avatarUrl: _nullableString(map['avatarUrl']),
      description: _text(map['description']),
      mutedUntil: DateTimeUtils.fromJson(map['mutedUntil']),
      muted: _bool(map['muted']),
      mutedReason: _text(map['mutedReason']),
      mutedBy: _string(map['mutedBy']),
      moderatorPermissions: _boolMap(map['moderatorPermissions']),
      adminNotes: _text(map['adminNotes']),
      requestedUnitType: _string(map['requestedUnitType']),
      requestedUnitName: _text(map['requestedUnitName']),
      blockedWrite: _bool(map['blockedWrite']),
      trustedAdminCandidate: _bool(map['trustedAdminCandidate']),
      mustChangePassword:
          _bool(map['mustChangePassword']) || _bool(map['mustSetPassword']),
      firstLoginTutorialCompleted:
          map.containsKey('firstLoginTutorialCompleted')
          ? _bool(map['firstLoginTutorialCompleted'])
          : true,
      fcmTokens: _stringList(map['fcmTokens']),
    );
  }

  factory AppUser.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    return AppUser.fromMap(doc.data() ?? {}, fallbackUid: doc.id);
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

String? _nullableString(Object? value) {
  final text = _string(value).trim();
  return text.isEmpty ? null : text;
}

String? _nullableText(Object? value) {
  final text = _text(value).trim();
  return text.isEmpty ? null : text;
}

bool _bool(Object? value) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  return false;
}

Map<String, bool> _boolMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, val) => MapEntry(key.toString(), _bool(val)));
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

List<String> _splitFullName(String value) {
  final parts = value.trim().split(RegExp(r'\s+'));
  if (parts.length < 2 || parts.first.isEmpty) return const [];
  return [parts.first, parts.skip(1).join(' ')];
}
