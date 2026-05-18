import 'package:flutter_test/flutter_test.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/models/chat_message.dart';

void main() {
  test('ChatMessage restores reactions', () {
    final message = ChatMessage.fromMap({
      'id': 'm1',
      'chatId': 'global',
      'scope': 'global',
      'senderId': 'u1',
      'senderDisplayName': 'Mlody (OSP Furmany)',
      'text': 'Test',
      'reactions': {
        'ok': ['u1', 'u2'],
      },
    }, fallbackId: 'fallback');

    expect(message.scope, ChatScope.global);
    expect(message.reactions['ok'], hasLength(2));
    expect(message.canRender, isTrue);
  });
}
