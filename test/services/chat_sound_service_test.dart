import 'package:flutter_test/flutter_test.dart';
import 'package:tarnobrzeg112/services/chat_sound_service.dart';

void main() {
  test('chat sound options use unique provided assets', () {
    final options = ChatSoundService.options;
    final assetPaths = options.map((option) => option.assetPath).toSet();
    final androidRawNames = options.map((option) => option.id).toSet();

    expect(options, hasLength(5));
    expect(assetPaths, hasLength(options.length));
    expect(androidRawNames, hasLength(options.length));
    expect(assetPaths, everyElement(startsWith('assets/sounds/')));
    expect(
      options.map((option) => option.id),
      containsAll(<String>[
        'cool_sms_tone',
        'door_knock',
        'e7_mms',
        'ninja_tone',
        'unique_sms',
      ]),
    );
  });
}
