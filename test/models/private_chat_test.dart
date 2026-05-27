import 'package:flutter_test/flutter_test.dart';
import 'package:tarnobrzeg112/models/private_chat.dart';

void main() {
  test('PrivateChat reads unified chats participants fields', () {
    final chat = PrivateChat.fromMap({
      'id': 'group_1',
      'type': 'group',
      'name': 'Czat okolice',
      'createdBy': 'u1',
      'participants': ['u1', 'u2'],
      'participantNames': ['Sasza (OSP Gorzyce)', 'Młody (OSP Furmany)'],
    });

    expect(chat.isGroup, isTrue);
    expect(chat.participantIds, ['u1', 'u2']);
    expect(chat.participantNames['u2'], 'Młody (OSP Furmany)');
    expect(chat.displayNameFor('u1'), 'Czat okolice');
  });

  test('PrivateChat tolerates legacy scalar unread and typing values', () {
    final chat = PrivateChat.fromMap({
      'id': 'private_1',
      'type': 'private',
      'participants': 'u1',
      'participantNames': {'u1': 112},
      'unreadCount': {'u1': '3'},
      'typing': {'u1': 'true'},
    });

    expect(chat.participantIds, ['u1']);
    expect(chat.participantNames['u1'], '112');
    expect(chat.unreadCount['u1'], 3);
    expect(chat.typing['u1'], isTrue);
  });

  test('PrivateChat restores chat sound and appearance settings', () {
    final chat = PrivateChat.fromMap({
      'id': 'main',
      'type': 'main',
      'participants': ['u1'],
      'themeColor': '#0891b2',
      'messageStyle': 'soft',
      'chatTheme': 'neon',
      'backgroundType': 'preset',
      'backgroundPreset': 'neon',
      'incomingSound': 'unique_sms',
      'privateSound': 'cool_sms_tone',
      'vibrationEnabled': false,
      'notificationMode': 'silent',
    });

    expect(chat.themeColor, '#0891b2');
    expect(chat.messageStyle, 'soft');
    expect(chat.backgroundPreset, 'neon');
    expect(chat.incomingSound, 'unique_sms');
    expect(chat.privateSound, 'cool_sms_tone');
    expect(chat.vibrationEnabled, isFalse);
    expect(chat.notificationMode, 'silent');
  });
}
