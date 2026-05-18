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
}
