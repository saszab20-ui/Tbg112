import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<bool> playBrowserSound(String assetPath, double volume) async {
  try {
    final audio = web.HTMLAudioElement()
      ..src = assetPath
      ..volume = volume.clamp(0, 1);
    await audio.play().toDart;
    return true;
  } on Object {
    return false;
  }
}
