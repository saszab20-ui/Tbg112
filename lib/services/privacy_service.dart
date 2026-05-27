import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PrivacyService {
  PrivacyService._();

  static const _channel = MethodChannel('pl.tarnobrzeg112/privacy');

  static Future<void> setSecureMode(bool enabled) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('setSecureMode', {'enabled': enabled});
    } on MissingPluginException {
      debugPrint('Privacy secure mode unavailable on this platform.');
    } on PlatformException catch (error) {
      debugPrint('Privacy secure mode error: ${error.code} ${error.message}');
    }
  }
}
