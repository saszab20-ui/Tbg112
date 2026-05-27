class FirestoreCollections {
  const FirestoreCollections._();

  static const users = 'users';
  static const units = 'units';
  static const chats = 'chats';
  static const notifications = 'notifications';
  static const events = 'events';
  static const reports = 'reports';
  static const moderationLogs = 'moderation_logs';
  static const pinnedMessages = 'pinned_messages';
  static const appSettings = 'app_settings';
  static const inviteCodes = 'invite_codes';

  // Legacy collection names kept only for reading old project history/docs.
  static const globalChat = 'global_chat';
  static const unitChats = 'unit_chats';
  static const privateChats = 'private_chats';
}
