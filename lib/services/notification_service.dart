import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tarnobrzeg112/core/app_constants.dart';
import 'package:tarnobrzeg112/services/chat_sound_service.dart';
import 'package:tarnobrzeg112/services/local_preferences.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background notification: ${message.messageId}');
}

class NotificationService {
  NotificationService(this._messaging);

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _openedRoutes =
      StreamController<String>.broadcast();
  String? _initialRoute;
  String? _currentUserId;

  void setCurrentUserId(String? uid) {
    _currentUserId = uid?.trim().isEmpty == true ? null : uid;
  }

  Future<void> initialize() async {
    if (!kIsWeb) {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }

    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    if (!kIsWeb) {
      const androidSettings = AndroidInitializationSettings(
        '@drawable/ic_notification',
      );
      const darwinSettings = DarwinInitializationSettings();
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );
      await _localNotifications.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) {
          final route = _routeFromPayload(response.payload);
          if (route != null) _openedRoutes.add(route);
        },
        onDidReceiveBackgroundNotificationResponse:
            notificationTapBackgroundHandler,
      );

      final channel = AndroidNotificationChannel(
        AppConstants.notificationChannelId,
        AppConstants.notificationChannelName,
        description: AppConstants.notificationChannelDescription,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        sound: const RawResourceAndroidNotificationSound(
          ChatSoundService.defaultIncomingSound,
        ),
      );
      const adminChannel = AndroidNotificationChannel(
        'tbg112_admin',
        'Tarnobrzeg 112 Admin',
        description: 'Powiadomienia administracyjne Tarnobrzeg 112',
        importance: Importance.high,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
      for (final option in ChatSoundService.options) {
        await _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(
              AndroidNotificationChannel(
                _channelIdForSound(option.id),
                'Czat: ${option.label}',
                description: 'Powiadomienia czatu z dźwiękiem ${option.label}',
                importance: Importance.high,
                playSound: true,
                enableVibration: true,
                sound: RawResourceAndroidNotificationSound(option.id),
              ),
            );
      }
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(adminChannel);
    }

    FirebaseMessaging.onMessage.listen((message) {
      if (!kIsWeb) _showForegroundMessage(message);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final route = _routeFor(message);
      if (route != null) _openedRoutes.add(route);
    });
    _initialRoute = _routeFor(await _messaging.getInitialMessage());
  }

  Future<String?> getToken() => _messaging.getToken();

  Stream<String> openedRoutes() async* {
    final initial = _initialRoute;
    if (initial != null) yield initial;
    yield* _openedRoutes.stream;
  }

  Future<void> clearChatNotifications(String chatId) async {
    if (kIsWeb) return;
    final id = _notificationIdForChat(chatId);
    final tag = 'chat_$chatId';
    await _localNotifications.cancel(id: id);
    await _localNotifications.cancel(id: id, tag: tag);
    await _localNotifications.cancel(id: 0, tag: tag);
  }

  Future<void> showLocalAlert({
    required String title,
    required String body,
    bool adminChannel = false,
  }) async {
    if (kIsWeb) return;
    final soundId = adminChannel
        ? ChatSoundService.defaultIncomingSound
        : ChatSoundService.defaultPrivateSound;
    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          adminChannel ? 'tbg112_admin' : AppConstants.notificationChannelId,
          adminChannel
              ? 'Tarnobrzeg 112 Admin'
              : AppConstants.notificationChannelName,
          channelDescription: adminChannel
              ? 'Powiadomienia administracyjne Tarnobrzeg 112'
              : AppConstants.notificationChannelDescription,
          icon: '@drawable/ic_notification',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          sound: RawResourceAndroidNotificationSound(soundId),
          vibrationPattern: Int64List.fromList([0, 120, 80, 120]),
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> _showForegroundMessage(RemoteMessage message) async {
    if (kIsWeb) return;
    final senderId = message.data['senderId']?.toString();
    final createdBy = message.data['createdBy']?.toString();
    if (_currentUserId != null &&
        (senderId == _currentUserId || createdBy == _currentUserId)) {
      return;
    }
    final notification = message.notification;
    final title =
        notification?.title ?? message.data['title'] ?? 'Tarnobrzeg 112';
    final body = notification?.body ?? message.data['body'] ?? '';
    final route = _routeFor(message);
    final chatId = message.data['chatId']?.toString() ?? '';
    final soundSettings = await _soundSettingsFromData(message.data);
    final payloadData = <String, Object?>{...message.data};
    if (route != null) payloadData['route'] = route;
    if (ChatSoundService.isCustom(soundSettings.soundId)) {
      unawaited(
        ChatSoundService.play(
          soundSettings.soundId,
          vibration: soundSettings.vibrationEnabled,
          mode: soundSettings.mode,
        ),
      );
    }
    await _localNotifications.show(
      id: _notificationIdForChat(
        chatId.isEmpty ? message.messageId ?? '' : chatId,
      ),
      title: title,
      body: body,
      payload: jsonEncode(payloadData),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelIdForSound(soundSettings.channelSoundId),
          AppConstants.notificationChannelName,
          channelDescription: AppConstants.notificationChannelDescription,
          icon: '@drawable/ic_notification',
          importance: Importance.high,
          priority: Priority.high,
          playSound:
              !ChatSoundService.isCustom(soundSettings.soundId) &&
              soundSettings.mode != 'silent',
          enableVibration: soundSettings.vibrationEnabled,
          sound: ChatSoundService.isCustom(soundSettings.soundId)
              ? null
              : RawResourceAndroidNotificationSound(soundSettings.soundId),
          vibrationPattern: soundSettings.vibrationEnabled
              ? Int64List.fromList([0, 120, 80, 120])
              : null,
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      ),
    );
  }

  String? _routeFor(RemoteMessage? message) {
    if (message == null) return null;
    final type = message.data['type'];
    if (type == 'pending_account') return '/admin/users?filter=pending';
    final route = message.data['route'];
    if (route is String && route.isNotEmpty) return route;
    final chatId = message.data['chatId'];
    final chatType = message.data['chatType'];
    final messageId = message.data['messageId'];
    final suffix = messageId is String && messageId.isNotEmpty
        ? '?messageId=$messageId'
        : '';
    if (chatId is! String || chatId.isEmpty) return null;
    if (chatType == 'main' || chatId == 'main') return '/chat/global$suffix';
    if (chatType == 'unit') {
      final unitId = chatId.replaceFirst(RegExp('^unit[_-]'), '');
      return '/chat/unit/$unitId$suffix';
    }
    if (chatType == 'private' || chatType == 'group') {
      return '/private/$chatId$suffix';
    }
    return null;
  }

  String? _routeFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final data = jsonDecode(payload);
      if (data is Map) {
        final route = data['route'];
        if (route is String && route.isNotEmpty) return route;
        return routeForNotificationData(
          data.map((key, value) => MapEntry('$key', value)),
        );
      }
    } on Object catch (error) {
      debugPrint('Notification payload parse failed: $error');
    }
    return null;
  }

  @visibleForTesting
  static String? routeForNotificationData(Map<String, Object?> data) {
    final type = data['type'];
    if (type == 'pending_account') return '/admin/users?filter=pending';
    final route = data['route'];
    if (route is String && route.isNotEmpty) return route;
    final chatId = data['chatId'];
    final chatType = data['chatType'];
    final messageId = data['messageId'];
    final suffix = messageId is String && messageId.isNotEmpty
        ? '?messageId=$messageId'
        : '';
    if (chatId is! String || chatId.isEmpty) return null;
    if (chatType == 'main' || chatId == 'main') return '/chat/global$suffix';
    if (chatType == 'unit') {
      final unitId = chatId.replaceFirst(RegExp('^unit[_-]'), '');
      return '/chat/unit/$unitId$suffix';
    }
    if (chatType == 'private' || chatType == 'group') {
      return '/private/$chatId$suffix';
    }
    return null;
  }

  int _notificationIdForChat(String chatId) {
    final source = chatId.isEmpty ? 'tarnobrzeg112' : chatId;
    return source.codeUnits.fold<int>(
      112,
      (hash, unit) => ((hash * 31) + unit) & 0x7fffffff,
    );
  }

  Future<_NotificationSoundSettings> _soundSettingsFromData(
    Map<String, dynamic> data,
  ) async {
    final chatId = data['chatId']?.toString() ?? '';
    final chatType = data['chatType']?.toString() ?? '';
    final uid = _currentUserId;
    if (uid != null && chatId.isNotEmpty) {
      try {
        final prefs = await loadLocalPreferences();
        final prefix =
            'chatPersonalization.${Uri.encodeComponent(uid)}.${Uri.encodeComponent(chatId)}';
        final personalSound = chatType == 'private' || chatType == 'group'
            ? prefs.getString('$prefix.privateSound')
            : prefs.getString('$prefix.incomingSound');
        final mode = prefs.getString('$prefix.notificationMode') ?? 'loud';
        final vibrationEnabled =
            prefs.getBool('$prefix.vibrationEnabled') ?? true;
        if (personalSound != null && ChatSoundService.isValid(personalSound)) {
          return _NotificationSoundSettings(
            soundId: personalSound,
            mode: mode,
            vibrationEnabled: vibrationEnabled,
          );
        }
      } on Object catch (error) {
        debugPrint('Notification personal sound load failed: $error');
      }
    }
    return _NotificationSoundSettings(
      soundId: _soundIdFromData(data),
      mode: 'loud',
      vibrationEnabled: true,
    );
  }

  String _soundIdFromData(Map<String, dynamic> data) {
    final sound = data['sound']?.toString() ?? '';
    if (ChatSoundService.options.any((option) => option.id == sound)) {
      return sound;
    }
    return ChatSoundService.defaultIncomingSound;
  }

  static String _channelIdForSound(String soundId) {
    return 'tbg112_chat_$soundId';
  }
}

class _NotificationSoundSettings {
  const _NotificationSoundSettings({
    required this.soundId,
    required this.mode,
    required this.vibrationEnabled,
  });

  final String soundId;
  final String mode;
  final bool vibrationEnabled;

  String get channelSoundId => ChatSoundService.isCustom(soundId)
      ? ChatSoundService.defaultIncomingSound
      : soundId;
}

@pragma('vm:entry-point')
void notificationTapBackgroundHandler(NotificationResponse response) {}
