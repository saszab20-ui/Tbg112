import 'package:flutter_test/flutter_test.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/models/app_user.dart';

void main() {
  AppUser user(UnitType type, String unitName) {
    return AppUser(
      uid: 'u_${type.name}',
      login: type.name,
      email: '${type.name}@tarnobrzeg112.local',
      firstName: '',
      lastName: '',
      nickname: type.label,
      phoneNumber: '',
      unitType: type,
      unitId: unitName.toLowerCase().replaceAll(' ', '-'),
      unitName: unitName,
      voivodeship: 'podkarpackie',
      county: 'tarnobrzeski',
      role: UserRole.user,
      accountStatus: AccountStatus.active,
      presenceStatus: PresenceStatus.offline,
      joinedAt: DateTime(2026, 1, 1),
      lastSeenAt: DateTime(2026, 1, 1),
    );
  }

  test('Media and Informator do not get automatic unit chat access', () {
    expect(user(UnitType.media, 'Redakcja').hasUnitChatAccess, isFalse);
    expect(user(UnitType.informator, 'Informator').hasUnitChatAccess, isFalse);
  });

  test('OSP PSP Policja and ZRM get unit chat access after unit approval', () {
    expect(user(UnitType.osp, 'OSP Gorzyce').hasUnitChatAccess, isTrue);
    expect(user(UnitType.psp, 'PSP Tarnobrzeg').hasUnitChatAccess, isTrue);
    expect(user(UnitType.policja, 'KMP Tarnobrzeg').hasUnitChatAccess, isTrue);
    expect(user(UnitType.zrm, 'ZRM Tarnobrzeg').hasUnitChatAccess, isTrue);
  });
}
