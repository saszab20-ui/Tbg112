import 'package:flutter_test/flutter_test.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/models/app_user.dart';

void main() {
  test('AppUser maps display name and permissions', () {
    final user = AppUser(
      uid: 'u1',
      login: 'sasza',
      email: 'test@example.com',
      firstName: 'Jan',
      lastName: 'Kowalski',
      nickname: 'Sasza',
      phoneNumber: '500600700',
      unitType: UnitType.osp,
      unitId: 'osp-gorzyce',
      unitName: 'OSP Gorzyce',
      voivodeship: 'podkarpackie',
      county: 'tarnobrzeski',
      role: UserRole.moderator,
      accountStatus: AccountStatus.active,
      presenceStatus: PresenceStatus.online,
      joinedAt: DateTime(2026, 1, 1),
      lastSeenAt: DateTime(2026, 1, 2),
    );

    expect(user.publicName, 'Sasza (OSP Gorzyce)');
    expect(user.isModerator, isTrue);
    expect(user.canWrite, isTrue);
    expect(AppUser.fromMap(user.toMap()).unitName, 'OSP Gorzyce');
  });

  test('AppUser prefers current serviceType over stale unitType', () {
    final user = AppUser.fromMap({
      'uid': 'admin1',
      'login': 'badura_admin',
      'authEmail': 'badura_admin@tarnobrzeg112.local',
      'firstName': 'Slawomir',
      'lastName': 'Badura',
      'nickname': 'Slawomir Badura',
      'serviceType': 'INFORMATOR',
      'unitType': 'osp',
      'unitName': 'OSP Gorzyce',
      'role': 'admin',
      'accountStatus': 'active',
    });

    expect(user.unitType, UnitType.informator);
  });

  test('AppUser uses first name on chat when nickname is empty', () {
    final user = AppUser(
      uid: 'u2',
      login: 'jan_nowak',
      email: 'jan@example.com',
      firstName: 'Jan',
      lastName: 'Nowak',
      nickname: '',
      phoneNumber: '',
      unitType: UnitType.informator,
      unitId: '',
      unitName: '',
      voivodeship: 'podkarpackie',
      county: 'tarnobrzeski',
      role: UserRole.user,
      accountStatus: AccountStatus.active,
      presenceStatus: PresenceStatus.offline,
      joinedAt: DateTime(2026, 1, 1),
      lastSeenAt: null,
    );

    expect(user.publicName, 'Jan (Informator)');
    expect(user.displayName, 'Jan Nowak');
    expect(user.firstNameForHome, 'Jan');
  });
}
