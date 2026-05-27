class AppConstants {
  const AppConstants._();

  static const appName = 'Tarnobrzeg 112';
  static const fullAppName =
      'Tarnobrzeg 112 - Ratownictwo Powiatu Tarnobrzeskiego';
  static const packageName = 'pl.tarnobrzeg112.app';
  static const safetyNotice =
      'Prywatny komunikator informacyjny. To nie jest oficjalny system alarmowy i nie zastępuje numeru 112.';
  static const technicalEmailDomain = 'tarnobrzeg112.local';
  static const devAdminMode = true;
  static const superAdminLogin = 'badura_admin';
  static const bootstrapAdminLogins = ['badura_admin', 'robak_admin'];
  static const trustedAdminLogins = ['robak_admin'];

  static const globalChatId = 'main';
  static const defaultCounty = 'tarnobrzeski';
  static const defaultVoivodeship = 'podkarpackie';

  static const messagesPageSize = 30;
  static const maxImageUploadBytes = 8 * 1024 * 1024;
  static const maxFileUploadBytes = 20 * 1024 * 1024;

  static const notificationChannelId = 'tbg112_chat_messages_v2';
  static const notificationChannelName = 'Wiadomości czatu';
  static const notificationChannelDescription =
      'Głośne powiadomienia o nowych wiadomościach czatu.';
  static const notificationSoundLoud = 'unique_sms';
}
