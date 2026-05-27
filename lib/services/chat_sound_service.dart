import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tarnobrzeg112/services/chat_sound_native_stub.dart'
    if (dart.library.io) 'package:tarnobrzeg112/services/chat_sound_native_io.dart';
import 'package:tarnobrzeg112/services/chat_sound_web_stub.dart'
    if (dart.library.html) 'package:tarnobrzeg112/services/chat_sound_web.dart';

class ChatSoundOption {
  const ChatSoundOption({
    required this.id,
    required this.label,
    required this.assetPath,
  });

  final String id;
  final String label;
  final String assetPath;
}

class ChatSoundService {
  static const defaultIncomingSound = 'unique_sms';
  static const defaultPrivateSound = 'cool_sms_tone';
  static const _customPrefix = 'custom:';

  static const options = <ChatSoundOption>[
    ChatSoundOption(
      id: 'cool_sms_tone',
      label: 'Cool SMS Tone',
      assetPath: 'assets/sounds/cool_sms_tone.mp3',
    ),
    ChatSoundOption(
      id: 'door_knock',
      label: 'Door Knock',
      assetPath: 'assets/sounds/door_knock.mp3',
    ),
    ChatSoundOption(
      id: 'e7_mms',
      label: 'E7 MMS',
      assetPath: 'assets/sounds/e7_mms.mp3',
    ),
    ChatSoundOption(
      id: 'ninja_tone',
      label: 'Ninja Tone',
      assetPath: 'assets/sounds/ninja_tone.mp3',
    ),
    ChatSoundOption(
      id: 'unique_sms',
      label: 'Unique SMS',
      assetPath: 'assets/sounds/unique_sms.mp3',
    ),
  ];

  static ChatSoundOption optionById(String id) {
    return options.firstWhere(
      (option) => option.id == id,
      orElse: () =>
          options.firstWhere((option) => option.id == defaultIncomingSound),
    );
  }

  static bool isValid(String id) {
    return isCustom(id) || options.any((option) => option.id == id);
  }

  static bool isCustom(String id) => id.startsWith(_customPrefix);

  static String customFileId({required String name, required String path}) {
    return '${_customPrefix}file:${_encode(path)}:${_encode(name)}';
  }

  static String customDataId({
    required String name,
    required String mimeType,
    required List<int> bytes,
  }) {
    final dataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
    return '${_customPrefix}data:${_encode(dataUrl)}:${_encode(name)}';
  }

  static String customLabel(String id) {
    final parts = _customParts(id);
    if (parts == null || parts.length < 3) return 'Własny dźwięk';
    final label = _decode(parts[2]);
    return label.trim().isEmpty ? 'Własny dźwięk' : label;
  }

  static Future<void> play(
    String id, {
    bool vibration = true,
    String mode = 'standard',
  }) async {
    if (vibration) {
      await _vibrate(mode);
    }
    if (mode == 'silent') return;

    final volume = mode == 'loud' ? 1.0 : 0.74;
    if (isCustom(id)) {
      final played = await _playCustom(id, volume);
      if (played) return;
      await _fallbackAlert();
      return;
    }

    final option = optionById(id);
    if (kIsWeb) {
      final assetUri = Uri.base.resolve('/assets/${option.assetPath}');
      final played = await playBrowserSound(assetUri.toString(), volume);
      if (played) return;
    }

    final player = AudioPlayer();
    try {
      await player.setAsset(option.assetPath);
      await player.setVolume(volume);
      await player.play();
      await player.processingStateStream.firstWhere(
        (state) => state == ProcessingState.completed,
      );
    } on Object {
      await _fallbackAlert();
    } finally {
      await player.dispose();
    }
  }

  static Future<void> preview(String id, {String mode = 'standard'}) {
    return play(id, vibration: false, mode: mode);
  }

  static Future<void> _vibrate(String mode) async {
    if (mode == 'loud') {
      await HapticFeedback.mediumImpact();
      return;
    }
    await HapticFeedback.lightImpact();
  }

  static Future<bool> _playCustom(String id, double volume) async {
    final parts = _customParts(id);
    if (parts == null || parts.length < 3) return false;
    final sourceType = parts[0];
    final source = _decode(parts[1]);
    if (sourceType == 'data') {
      if (kIsWeb) return playBrowserSound(source, volume);
      final player = AudioPlayer();
      try {
        final path = await materializeCustomSoundDataUrl(
          source,
          _decode(parts[2]),
        );
        if (path != null) {
          await player.setFilePath(path);
        } else {
          await player.setUrl(source);
        }
        await player.setVolume(volume);
        await player.play();
        await player.processingStateStream.firstWhere(
          (state) => state == ProcessingState.completed,
        );
        return true;
      } on Object {
        return false;
      } finally {
        await player.dispose();
      }
    }
    if (sourceType == 'file') {
      if (kIsWeb) return false;
      final player = AudioPlayer();
      try {
        await player.setFilePath(source);
        await player.setVolume(volume);
        await player.play();
        await player.processingStateStream.firstWhere(
          (state) => state == ProcessingState.completed,
        );
        return true;
      } on Object {
        return false;
      } finally {
        await player.dispose();
      }
    }
    return false;
  }

  static Future<void> _fallbackAlert() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
    } on Object {
      // A browser may block preview audio without a direct gesture. In that
      // case we fail silently instead of showing a technical error.
    }
  }

  static List<String>? _customParts(String id) {
    if (!isCustom(id)) return null;
    return id.substring(_customPrefix.length).split(':');
  }

  static String _encode(String value) {
    return base64UrlEncode(utf8.encode(value));
  }

  static String _decode(String value) {
    return utf8.decode(base64Url.decode(value));
  }
}
