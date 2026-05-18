import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tarnobrzeg112/core/app_constants.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
import 'package:tarnobrzeg112/screens/admin/admin_panel_screen.dart';
import 'package:tarnobrzeg112/screens/admin/deleted_messages_screen.dart';
import 'package:tarnobrzeg112/screens/admin/logs_screen.dart';
import 'package:tarnobrzeg112/screens/admin/muted_users_screen.dart';
import 'package:tarnobrzeg112/screens/admin/reports_screen.dart';
import 'package:tarnobrzeg112/screens/admin/units_management_screen.dart';
import 'package:tarnobrzeg112/screens/admin/users_management_screen.dart';
import 'package:tarnobrzeg112/screens/auth/forgot_password_screen.dart';
import 'package:tarnobrzeg112/screens/auth/blocked_account_screen.dart';
import 'package:tarnobrzeg112/screens/auth/loading_screen.dart';
import 'package:tarnobrzeg112/screens/auth/login_screen.dart';
import 'package:tarnobrzeg112/screens/auth/onboarding_screen.dart';
import 'package:tarnobrzeg112/screens/auth/pending_approval_screen.dart';
import 'package:tarnobrzeg112/screens/auth/register_screen.dart';
import 'package:tarnobrzeg112/screens/chat/global_chat_screen.dart';
import 'package:tarnobrzeg112/screens/chat/chat_list_screen.dart';
import 'package:tarnobrzeg112/screens/chat/chat_settings_screen.dart';
import 'package:tarnobrzeg112/screens/chat/create_group_chat_screen.dart';
import 'package:tarnobrzeg112/screens/chat/invite_join_screen.dart';
import 'package:tarnobrzeg112/screens/chat/private_chat_screen.dart';
import 'package:tarnobrzeg112/screens/chat/private_chats_screen.dart';
import 'package:tarnobrzeg112/screens/chat/unit_chat_screen.dart';
import 'package:tarnobrzeg112/screens/home/home_screen.dart';
import 'package:tarnobrzeg112/screens/moderator/moderator_panel_screen.dart';
import 'package:tarnobrzeg112/screens/notifications_screen.dart';
import 'package:tarnobrzeg112/screens/profile/edit_profile_screen.dart';
import 'package:tarnobrzeg112/screens/profile/profile_screen.dart';
import 'package:tarnobrzeg112/screens/settings/change_password_screen.dart';
import 'package:tarnobrzeg112/screens/settings/settings_screen.dart';
import 'package:tarnobrzeg112/screens/splash_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final profileState = ref.watch(currentAppUserProvider);

  return GoRouter(
    initialLocation: RoutePaths.splash,
    redirect: (context, state) {
      final location = state.uri.path;
      final publicRoute = _publicRoutes.contains(location);

      if (authState.isLoading) {
        return _routeToLoading(location, 'authState loading');
      }

      if (authState.hasError) {
        return _routeToLoading(location, 'authState error: ${authState.error}');
      }

      final firebaseUser = authState.asData?.value;
      if (firebaseUser == null) {
        if (location == RoutePaths.login || publicRoute) return null;
        debugPrint('AUTH ROUTER -> login reason=null Firebase user');
        return publicRoute ? null : RoutePaths.login;
      }

      final isDevAdmin =
          AppConstants.devAdminMode &&
          firebaseUser.email?.toLowerCase() ==
              '${AppConstants.superAdminLogin}@${AppConstants.technicalEmailDomain}';

      if (!isDevAdmin) {
        if (profileState.isLoading) {
          return _routeToLoading(location, 'profile loading');
        }
        if (profileState.hasError) {
          return _routeToLoading(
            location,
            'profile error: ${profileState.error}',
          );
        }
        final profile = profileState.asData?.value;
        if (profile == null) {
          return _routeToLoading(location, 'profile missing');
        }
        if (profile.accountStatus == AccountStatus.pending) {
          debugPrint('AUTH ROUTER -> pending reason=accountStatus pending');
          return location == RoutePaths.pendingApproval
              ? null
              : RoutePaths.pendingApproval;
        }
        if (profile.accountStatus != AccountStatus.active) {
          debugPrint(
            'AUTH ROUTER -> blocked reason=accountStatus '
            '${profile.accountStatus.name}',
          );
          return location == RoutePaths.blockedAccount
              ? null
              : RoutePaths.blockedAccount;
        }
      }

      if (location == RoutePaths.splash ||
          location == RoutePaths.loading ||
          publicRoute ||
          location == RoutePaths.pendingApproval ||
          location == RoutePaths.blockedAccount) {
        debugPrint(
          'AUTH ROUTER -> ${RoutePaths.home} reason=Firebase user exists '
          'uid=${firebaseUser.uid}',
        );
        return RoutePaths.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.loading,
        builder: (context, state) => const LoadingScreen(),
      ),
      GoRoute(
        path: RoutePaths.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: RoutePaths.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: RoutePaths.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: RoutePaths.pendingApproval,
        builder: (context, state) => const PendingApprovalScreen(),
      ),
      GoRoute(
        path: RoutePaths.blockedAccount,
        builder: (context, state) => const BlockedAccountScreen(),
      ),
      GoRoute(
        path: RoutePaths.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: RoutePaths.chats,
        builder: (context, state) => const ChatListScreen(),
      ),
      GoRoute(
        path: RoutePaths.globalChat,
        builder: (context, state) => const GlobalChatScreen(),
      ),
      GoRoute(
        path: '${RoutePaths.unitChatBase}/:unitId',
        builder: (context, state) {
          return UnitChatScreen(unitId: state.pathParameters['unitId'] ?? '');
        },
      ),
      GoRoute(
        path: '${RoutePaths.inviteBase}/:inviteCode',
        builder: (context, state) {
          return InviteJoinScreen(
            inviteCode: state.pathParameters['inviteCode'] ?? '',
          );
        },
      ),
      GoRoute(
        path: RoutePaths.privateChats,
        builder: (context, state) => const PrivateChatsScreen(),
      ),
      GoRoute(
        path: RoutePaths.createGroupChat,
        builder: (context, state) => const CreateGroupChatScreen(),
      ),
      GoRoute(
        path: '${RoutePaths.privateChats}/:chatId',
        builder: (context, state) {
          return PrivateChatScreen(
            chatId: state.pathParameters['chatId'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '${RoutePaths.chatSettingsBase}/:chatId',
        builder: (context, state) {
          return ChatSettingsScreen(
            chatId: state.pathParameters['chatId'] ?? '',
          );
        },
      ),
      GoRoute(
        path: RoutePaths.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: RoutePaths.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.changePassword,
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminPanel,
        builder: (context, state) => const AdminPanelScreen(),
      ),
      GoRoute(
        path: RoutePaths.moderatorPanel,
        builder: (context, state) => const ModeratorPanelScreen(),
      ),
      GoRoute(
        path: RoutePaths.usersManagement,
        builder: (context, state) => const UsersManagementScreen(),
      ),
      GoRoute(
        path: RoutePaths.mutedUsers,
        builder: (context, state) => const MutedUsersScreen(),
      ),
      GoRoute(
        path: RoutePaths.unitsManagement,
        builder: (context, state) => const UnitsManagementScreen(),
      ),
      GoRoute(
        path: RoutePaths.reports,
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: RoutePaths.logs,
        builder: (context, state) => const LogsScreen(),
      ),
      GoRoute(
        path: RoutePaths.deletedMessages,
        builder: (context, state) => const DeletedMessagesScreen(),
      ),
    ],
  );
});

const _publicRoutes = {
  RoutePaths.onboarding,
  RoutePaths.login,
  RoutePaths.register,
  RoutePaths.forgotPassword,
};

String? _routeToLoading(String location, String reason) {
  debugPrint('AUTH ROUTER -> loading reason=$reason');
  return location == RoutePaths.loading ? null : RoutePaths.loading;
}
