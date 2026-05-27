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

  test(
    'ChatMessage tolerates legacy string counters and image attachments',
    () {
      final message = ChatMessage.fromMap({
        'id': 'm2',
        'chatId': 'main',
        'scope': 'main',
        'senderId': 'u1',
        'senderDisplayName': 'SasBad (OSP Gorzyce)',
        'text': '',
        'mediaType': 'file',
        'reportCount': '0',
        'attachments': [
          {
            'url': 'https://example.com/ikona.png',
            'fileName': 'Ikona.png',
            'contentType': 'image/png',
            'sizeBytes': '1024',
          },
        ],
        'reactions': {'ok': 'u1'},
      }, fallbackId: 'fallback');

      expect(message.reportCount, 0);
      expect(message.mediaType, ChatMediaType.image);
      expect(message.attachments.single.mediaType, ChatMediaType.image);
      expect(message.attachments.single.sizeBytes, 1024);
      expect(message.reactions['ok'], ['u1']);
    },
  );

  test('ChatMessage repairs legacy Polish text from Firestore', () {
    final message = ChatMessage.fromMap({
      'id': 'm3',
      'chatId': 'main',
      'scope': 'main',
      'senderId': 'system',
      'senderDisplayName': 'System',
      'text': 'Do??czy?e? do czatu',
    }, fallbackId: 'fallback');

    expect(message.text, 'Dołączyłeś do czatu');
  });
}
