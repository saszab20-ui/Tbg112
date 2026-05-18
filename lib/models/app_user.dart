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
  final List<String> fcmTokens;

  String get publicName {
    final cleanNickname = nickname.trim().isEmpty ? login : nickname.trim();
    final cleanUnit = unitName.trim();
    if (cleanUnit.isEmpty &&
        (unitType == UnitType.media || unitType == UnitType.informator)) {
      return '$cleanNickname (${unitType.label})';
    }
    if (cleanUnit.isEmpty) return cleanNickname;
    return '$cleanNickname ($cleanUnit)';
  }

  String get fullName => '$firstName $lastName';
  String get phoneNumberOrDash =>
      phoneNumber.trim().isEmpty ? '-' : phoneNumber;
  String get initials => TextUtils.initials(nickname);
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
      'nickname': nickname,
      'phoneNumber': phoneNumber,
      'unitType': unitType.name,
      'serviceType': unitType.label,
      'unitId': unitId,
      'unitName': unitName,
      'voivodeship': voivodeship,
      'county': county,
      'role': role.name,
      'accountStatus': accountStatus.name,
      'presenceStatus': presenceStatus.name,
      'joinedAt': Timestamp.fromDate(joinedAt),
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
      'fcmTokens': fcmTokens,
      'displayName': fullName,
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
    final unitName = (map['unitName'] as String?) ?? '';
    final email =
        (map['authEmail'] as String?) ?? (map['email'] as String?) ?? '';
    final login = (map['login'] as String?) ?? email.split('@').first;
    return AppUser(
      uid: (map['uid'] as String?) ?? fallbackUid ?? '',
      login: login,
      email: email,
      firstName: (map['firstName'] as String?) ?? '',
      lastName: (map['lastName'] as String?) ?? '',
      nickname: (map['nickname'] as String?) ?? '',
      phoneNumber: (map['phoneNumber'] as String?) ?? '',
      unitType: UnitType.fromWire(
        (map['unitType'] as String?) ?? (map['serviceType'] as String?),
      ),
      unitId: (map['unitId'] as String?) ?? TextUtils.normalizeId(unitName),
      unitName: unitName,
      voivodeship: (map['voivodeship'] as String?) ?? '',
      county: (map['county'] as String?) ?? '',
      role: UserRole.fromWire(map['role'] as String?),
      accountStatus: AccountStatus.fromWire(map['accountStatus'] as String?),
      presenceStatus: PresenceStatus.fromWire(map['presenceStatus'] as String?),
      joinedAt: DateTimeUtils.fromJson(map['joinedAt']) ?? DateTime.now(),
      lastSeenAt: DateTimeUtils.fromJson(map['lastSeenAt']),
      avatarUrl: map['avatarUrl'] as String?,
      description: (map['description'] as String?) ?? '',
      mutedUntil: DateTimeUtils.fromJson(map['mutedUntil']),
      muted: (map['muted'] as bool?) ?? false,
      mutedReason: (map['mutedReason'] as String?) ?? '',
      mutedBy: (map['mutedBy'] as String?) ?? '',
      moderatorPermissions: Map<String, bool>.from(
        (map['moderatorPermissions'] as Map?) ?? const {},
      ),
      adminNotes: (map['adminNotes'] as String?) ?? '',
      requestedUnitType: (map['requestedUnitType'] as String?) ?? '',
      requestedUnitName: (map['requestedUnitName'] as String?) ?? '',
      blockedWrite: (map['blockedWrite'] as bool?) ?? false,
      trustedAdminCandidate: (map['trustedAdminCandidate'] as bool?) ?? false,
      fcmTokens: List<String>.from((map['fcmTokens'] as List?) ?? const []),
    );
  }

  factory AppUser.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    return AppUser.fromMap(doc.data() ?? {}, fallbackUid: doc.id);
  }
}
