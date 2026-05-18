class RoutePaths {
  const RoutePaths._();

  static const splash = '/';
  static const loading = '/loading';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const pendingApproval = '/pending-approval';
  static const blockedAccount = '/blocked-account';
  static const home = '/home';
  static const chats = '/chats';
  static const globalChat = '/chat/global';
  static const unitChatBase = '/chat/unit';
  static const inviteBase = '/chat/invite';
  static const privateChats = '/private';
  static const createGroupChat = '/private/create-group';
  static const chatSettingsBase = '/chat-settings';
  static const notifications = '/notifications';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const settings = '/settings';
  static const changePassword = '/settings/password';
  static const adminPanel = '/admin';
  static const moderatorPanel = '/moderator';
  static const usersManagement = '/admin/users';
  static const mutedUsers = '/admin/muted-users';
  static const unitsManagement = '/admin/units';
  static const reports = '/admin/reports';
  static const logs = '/admin/logs';
  static const deletedMessages = '/admin/deleted-messages';

  static String unitChat(String unitId) => '$unitChatBase/$unitId';
  static String invite(String inviteCode) => '$inviteBase/$inviteCode';
  static String privateChat(String chatId) => '$privateChats/$chatId';
  static String chatSettings(String chatId) => '$chatSettingsBase/$chatId';
}
