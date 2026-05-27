import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:tarnobrzeg112/services/local_preferences.dart';

final chatSendSoundsEnabledProvider = StateProvider<bool>((ref) => true);
final chatReceiveSoundsEnabledProvider = StateProvider<bool>((ref) => true);
final messageSoundLevelProvider = StateProvider<String>((ref) => 'unique_sms');
final messageVibrationEnabledProvider = StateProvider<bool>((ref) => true);
final newAccountSoundsEnabledProvider = StateProvider<bool>((ref) => true);
final privacyModeEnabledProvider = StateProvider<bool>((ref) => true);

final chatSoundsEnabledProvider = chatSendSoundsEnabledProvider;

class ChatPersonalizationKey {
  const ChatPersonalizationKey({required this.uid, required this.chatId});

  final String uid;
  final String chatId;

  @override
  bool operator ==(Object other) {
    return other is ChatPersonalizationKey &&
        other.uid == uid &&
        other.chatId == chatId;
  }

  @override
  int get hashCode => Object.hash(uid, chatId);
}

class ChatPersonalizationSettings {
  const ChatPersonalizationSettings({
    this.themeColor,
    this.messageStyle,
    this.chatTheme,
    this.backgroundType,
    this.backgroundImageUrl,
    this.backgroundPreset,
    this.incomingSound,
    this.privateSound,
    this.newAccountSound,
    this.announcementSound,
    this.eventSound,
    this.mentionSound,
    this.vibrationEnabled,
    this.notificationMode,
  });

  final String? themeColor;
  final String? messageStyle;
  final String? chatTheme;
  final String? backgroundType;
  final String? backgroundImageUrl;
  final String? backgroundPreset;
  final String? incomingSound;
  final String? privateSound;
  final String? newAccountSound;
  final String? announcementSound;
  final String? eventSound;
  final String? mentionSound;
  final bool? vibrationEnabled;
  final String? notificationMode;
}

final chatPersonalizationRevisionProvider = StateProvider<int>((ref) => 0);

final chatPersonalizationProvider =
    FutureProvider.family<ChatPersonalizationSettings, ChatPersonalizationKey>((
      ref,
      key,
    ) async {
      ref.watch(chatPersonalizationRevisionProvider);
      final prefs = await loadLocalPreferences();
      final prefix = _chatPersonalizationPrefix(key);
      return ChatPersonalizationSettings(
        themeColor: prefs.getString('$prefix.themeColor'),
        messageStyle: prefs.getString('$prefix.messageStyle'),
        chatTheme: prefs.getString('$prefix.chatTheme'),
        backgroundType: prefs.getString('$prefix.backgroundType'),
        backgroundImageUrl: prefs.getString('$prefix.backgroundImageUrl'),
        backgroundPreset: prefs.getString('$prefix.backgroundPreset'),
        incomingSound: prefs.getString('$prefix.incomingSound'),
        privateSound: prefs.getString('$prefix.privateSound'),
        newAccountSound: prefs.getString('$prefix.newAccountSound'),
        announcementSound: prefs.getString('$prefix.announcementSound'),
        eventSound: prefs.getString('$prefix.eventSound'),
        mentionSound: prefs.getString('$prefix.mentionSound'),
        vibrationEnabled: prefs.getBool('$prefix.vibrationEnabled'),
        notificationMode: prefs.getString('$prefix.notificationMode'),
      );
    });

Future<void> saveChatPersonalization({
  required ChatPersonalizationKey key,
  required ChatPersonalizationSettings settings,
}) async {
  final prefs = await loadLocalPreferences();
  final prefix = _chatPersonalizationPrefix(key);
  await prefs.setString('$prefix.themeColor', settings.themeColor ?? '');
  await prefs.setString('$prefix.messageStyle', settings.messageStyle ?? '');
  await prefs.setString('$prefix.chatTheme', settings.chatTheme ?? '');
  await prefs.setString(
    '$prefix.backgroundType',
    settings.backgroundType ?? '',
  );
  await prefs.setString(
    '$prefix.backgroundImageUrl',
    settings.backgroundImageUrl ?? '',
  );
  await prefs.setString(
    '$prefix.backgroundPreset',
    settings.backgroundPreset ?? '',
  );
  await prefs.setString('$prefix.incomingSound', settings.incomingSound ?? '');
  await prefs.setString('$prefix.privateSound', settings.privateSound ?? '');
  await prefs.setString(
    '$prefix.newAccountSound',
    settings.newAccountSound ?? '',
  );
  await prefs.setString(
    '$prefix.announcementSound',
    settings.announcementSound ?? '',
  );
  await prefs.setString('$prefix.eventSound', settings.eventSound ?? '');
  await prefs.setString('$prefix.mentionSound', settings.mentionSound ?? '');
  await prefs.setBool(
    '$prefix.vibrationEnabled',
    settings.vibrationEnabled ?? true,
  );
  await prefs.setString(
    '$prefix.notificationMode',
    settings.notificationMode ?? '',
  );
}

String _chatPersonalizationPrefix(ChatPersonalizationKey key) {
  final uid = Uri.encodeComponent(key.uid);
  final chatId = Uri.encodeComponent(key.chatId);
  return 'chatPersonalization.$uid.$chatId';
}
