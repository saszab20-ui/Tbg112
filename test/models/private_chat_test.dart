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
      'inviteCode': 'ABC123',
      'inviteLink': 'tarnobrzeg112://chat/invite/ABC123',
    });

    expect(chat.isGroup, isTrue);
    expect(chat.participantIds, ['u1', 'u2']);
    expect(chat.participantNames['u2'], 'Młody (OSP Furmany)');
    expect(chat.displayNameFor('u1'), 'Czat okolice');
    expect(chat.inviteLink, 'tarnobrzeg112://chat/invite/ABC123');
  });
}
