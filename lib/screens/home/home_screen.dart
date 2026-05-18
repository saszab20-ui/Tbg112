import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tarnobrzeg112/core/app_constants.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
import 'package:tarnobrzeg112/themes/app_colors.dart';
import 'package:tarnobrzeg112/utils/error_utils.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/empty_state.dart';
import 'package:tarnobrzeg112/widgets/glass_panel.dart';
import 'package:tarnobrzeg112/widgets/tbg_logo.dart';
import 'package:tarnobrzeg112/widgets/user_avatar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _tokenSaved = false;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentAppUserProvider);
    final activeUsers =
        ref.watch(activeUsersProvider).asData?.value ?? const [];
    final pendingCount =
        ref.watch(pendingUsersProvider).asData?.value.length ?? 0;
    final user = userAsync.asData?.value;
    if (user != null && !_tokenSaved) {
      _tokenSaved = true;
      Future.microtask(() async {
        try {
          final token = await ref.read(notificationServiceProvider).getToken();
          if (token != null) {
            await ref
                .read(usersRepositoryProvider)
                .saveFcmToken(user.uid, token);
          }
        } on Object catch (error) {
          debugPrint('AUTH DEBUG FCM token save skipped: $error');
        }
      });
    }

    return AppScaffold(
      title: AppConstants.appName,
      currentIndex: 0,
      actions: [
        IconButton(
          tooltip: 'Wyloguj',
          onPressed: () =>
              ref.read(authRepositoryProvider).signOut(reason: 'home_button'),
          icon: const Icon(Icons.logout),
        ),
        IconButton(
          tooltip: 'Ustawienia',
          onPressed: () => context.go(RoutePaths.settings),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.cloud_off,
          title: 'Brak połączenia',
          message: ErrorUtils.readable(error),
          actionLabel: 'Odśwież',
          onAction: () => ref.invalidate(currentAppUserProvider),
        ),
        data: (user) {
          if (user == null) {
            return const EmptyState(
              icon: Icons.person_off,
              title: 'Brak profilu',
              message: 'Zaloguj się ponownie lub skontaktuj z administratorem.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassPanel(
                child: Row(
                  children: [
                    const TbgLogo(size: 42, showText: false),
                    const SizedBox(width: 12),
                    UserAvatar(user: user, radius: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName.trim().isEmpty
                                ? user.publicName
                                : user.fullName,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${user.role.label} • ${user.accountStatus.label}',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.unitName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    OnlineAvatarStack(users: activeUsers),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _HomeTile(
                icon: Icons.forum,
                title: 'Czaty',
                subtitle: 'Czat główny, jednostki, grupy i prywatne rozmowy',
                onTap: () => context.go(RoutePaths.chats),
              ),
              _HomeTile(
                icon: Icons.groups_2,
                title: 'Kanał jednostki',
                subtitle: user.unitName,
                onTap: () => context.go(RoutePaths.unitChat(user.unitId)),
              ),
              _HomeTile(
                icon: Icons.lock,
                title: 'Prywatne rozmowy',
                subtitle: 'Rozmowy 1:1',
                onTap: () => context.go(RoutePaths.privateChats),
              ),
              if (user.isModerator)
                _HomeTile(
                  icon: Icons.admin_panel_settings,
                  title: 'Panel moderatora',
                  subtitle: 'Moderacja wiadomości i jednostki',
                  onTap: () => context.go(RoutePaths.moderatorPanel),
                ),
              if (user.isAdmin)
                _HomeTile(
                  icon: Icons.security,
                  title: 'Panel admina',
                  subtitle: 'Nowe konta do akceptacji: $pendingCount',
                  badgeCount: pendingCount,
                  onTap: () => context.go(RoutePaths.adminPanel),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HomeTile extends StatelessWidget {
  const _HomeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: badgeCount > 0
            ? Badge(
                label: Text('$badgeCount'),
                child: Icon(icon, color: AppColors.orange),
              )
            : Icon(icon, color: AppColors.orange),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
