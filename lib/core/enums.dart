enum UserRole {
  user,
  moderator,
  admin;

  String get label => switch (this) {
    UserRole.user => 'Użytkownik',
    UserRole.moderator => 'Moderator',
    UserRole.admin => 'Admin',
  };

  String get shortLabel => switch (this) {
    UserRole.user => 'USER',
    UserRole.moderator => 'MODERATOR',
    UserRole.admin => 'ADMIN',
  };

  static UserRole fromWire(String? value) => UserRole.values.firstWhere(
    (role) => role.name == value,
    orElse: () => UserRole.user,
  );
}

enum UnitType {
  osp,
  psp,
  policja,
  zrm,
  media,
  informator,
  inne,
  ratownikMedyczny,
  kierowcaKaretki,
  dyspozytor;

  String get label => switch (this) {
    UnitType.osp => 'OSP',
    UnitType.psp => 'PSP',
    UnitType.policja => 'Policja',
    UnitType.zrm => 'ZRM',
    UnitType.media => 'Media',
    UnitType.informator => 'Informator',
    UnitType.inne => 'Inne',
    UnitType.ratownikMedyczny => 'Ratownik medyczny',
    UnitType.kierowcaKaretki => 'Kierowca karetki',
    UnitType.dyspozytor => 'Dyspozytor',
  };

  String get badgeLabel => switch (this) {
    UnitType.media => 'MEDIA',
    UnitType.informator => 'INFORMATOR',
    UnitType.osp => 'OSP',
    UnitType.psp => 'PSP',
    UnitType.policja => 'POLICJA',
    UnitType.zrm => 'ZRM',
    UnitType.inne => 'INNE',
    UnitType.ratownikMedyczny => 'RATOWNIK',
    UnitType.kierowcaKaretki => 'KIEROWCA',
    UnitType.dyspozytor => 'DYSPOZYTOR',
  };

  bool get hasOwnUnitChat => switch (this) {
    UnitType.osp || UnitType.psp || UnitType.policja || UnitType.zrm => true,
    UnitType.media ||
    UnitType.informator ||
    UnitType.inne ||
    UnitType.ratownikMedyczny ||
    UnitType.kierowcaKaretki ||
    UnitType.dyspozytor => false,
  };

  static UnitType fromWire(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == 'media') return UnitType.media;
    if (normalized == 'informator') return UnitType.informator;
    if (normalized == 'osp') return UnitType.osp;
    if (normalized == 'psp') return UnitType.psp;
    if (normalized == 'policja') return UnitType.policja;
    if (normalized == 'zrm') return UnitType.zrm;
    if (normalized == 'inne' || normalized == 'inne służby') {
      return UnitType.inne;
    }
    if (normalized == 'ratownik' ||
        normalized == 'ratownik medyczny' ||
        normalized == 'ratownik_medyczny') {
      return UnitType.ratownikMedyczny;
    }
    if (normalized == 'kierowca' ||
        normalized == 'kierowca karetki' ||
        normalized == 'kierowca_karetki') {
      return UnitType.kierowcaKaretki;
    }
    if (normalized == 'dyspozytor') return UnitType.dyspozytor;
    return UnitType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => UnitType.inne,
    );
  }
}

enum AccountStatus {
  pending,
  active,
  rejected,
  banned,
  suspended,
  deleted;

  String get label => switch (this) {
    AccountStatus.pending => 'Oczekuje',
    AccountStatus.active => 'Aktywne',
    AccountStatus.rejected => 'Odrzucone',
    AccountStatus.banned => 'Zbanowane',
    AccountStatus.suspended => 'Zawieszone',
    AccountStatus.deleted => 'Usunięte',
  };

  static AccountStatus fromWire(String? value) =>
      AccountStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => AccountStatus.pending,
      );
}

enum PresenceStatus {
  online,
  offline,
  busy,
  invisible,
  unavailable,
  manual;

  String get label => switch (this) {
    PresenceStatus.online => 'Online',
    PresenceStatus.offline => 'Offline',
    PresenceStatus.busy => 'Zajęty',
    PresenceStatus.invisible => 'Niewidoczny',
    PresenceStatus.unavailable => 'Niedostępny',
    PresenceStatus.manual => 'Własny status',
  };

  static PresenceStatus fromWire(String? value) =>
      PresenceStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => PresenceStatus.offline,
      );
}

enum ChatScope {
  global,
  unit,
  private,
  group;

  static ChatScope fromWire(String? value) {
    if (value == 'main') return ChatScope.global;
    return ChatScope.values.firstWhere(
      (scope) => scope.name == value,
      orElse: () => ChatScope.global,
    );
  }

  String get wireName => switch (this) {
    ChatScope.global => 'main',
    ChatScope.unit => 'unit',
    ChatScope.private => 'private',
    ChatScope.group => 'group',
  };
}

enum ChatMediaType {
  text,
  image,
  video,
  voice,
  file;

  String get label => switch (this) {
    ChatMediaType.text => 'Tekst',
    ChatMediaType.image => 'Zdjęcie',
    ChatMediaType.video => 'Wideo',
    ChatMediaType.voice => 'Głosówka',
    ChatMediaType.file => 'Plik',
  };

  static ChatMediaType fromWire(String? value) =>
      ChatMediaType.values.firstWhere(
        (type) => type.name == value,
        orElse: () => ChatMediaType.text,
      );
}

enum NotificationKind {
  message,
  privateMessage,
  mention,
  pinnedMessage,
  adminAnnouncement;

  String get label => switch (this) {
    NotificationKind.message => 'Nowa wiadomość',
    NotificationKind.privateMessage => 'Prywatna wiadomość',
    NotificationKind.mention => 'Oznaczenie',
    NotificationKind.pinnedMessage => 'Przypięta wiadomość',
    NotificationKind.adminAnnouncement => 'Ogłoszenie',
  };

  static NotificationKind fromWire(String? value) =>
      NotificationKind.values.firstWhere(
        (kind) => kind.name == value,
        orElse: () => NotificationKind.message,
      );
}

enum ReportReason {
  spam,
  offensive,
  impersonation,
  abuse;

  String get label => switch (this) {
    ReportReason.spam => 'Spam',
    ReportReason.offensive => 'Obraźliwa treść',
    ReportReason.impersonation => 'Podszywanie się',
    ReportReason.abuse => 'Nadużycie',
  };

  static ReportReason fromWire(String? value) => ReportReason.values.firstWhere(
    (reason) => reason.name == value,
    orElse: () => ReportReason.abuse,
  );
}
