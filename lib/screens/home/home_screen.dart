import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:tarnobrzeg112/core/app_constants.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';
import 'package:tarnobrzeg112/providers/settings_providers.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
import 'package:tarnobrzeg112/themes/app_colors.dart';
import 'package:tarnobrzeg112/utils/error_utils.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/empty_state.dart';
import 'package:tarnobrzeg112/widgets/glass_panel.dart';
import 'package:tarnobrzeg112/widgets/user_avatar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _tokenSaved = false;
  int _lastPendingToastCount = 0;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentAppUserProvider);
    final activeUsers =
        ref.watch(activeUsersProvider).asData?.value ?? const [];
    final pendingCount =
        ref.watch(pendingUsersProvider).asData?.value.length ?? 0;
    final newAccountSoundsEnabled = ref.watch(newAccountSoundsEnabledProvider);
    final user = userAsync.asData?.value;
    if (user?.isAdmin == true &&
        pendingCount > 0 &&
        pendingCount != _lastPendingToastCount) {
      _lastPendingToastCount = pendingCount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nowe konto oczekuje na akceptację')),
        );
        if (newAccountSoundsEnabled) {
          ref
              .read(notificationServiceProvider)
              .showLocalAlert(
                title: 'Nowe konto do akceptacji',
                body: 'Otwórz panel admina, aby sprawdzić zgłoszenie.',
                adminChannel: true,
              );
        }
      });
    } else if (pendingCount == 0 && _lastPendingToastCount != 0) {
      _lastPendingToastCount = 0;
    }
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
          onPressed: () => context.push(RoutePaths.settings),
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
                child: _StartUserCard(
                  user: user,
                  activeCount: activeUsers.length,
                ),
              ),
              const SizedBox(height: 14),
              _HomeTile(
                icon: Icons.forum,
                title: 'Czaty',
                subtitle: 'Czat główny, jednostki, grupy i prywatne rozmowy',
                onTap: () => context.go(RoutePaths.chats),
              ),
              if (user.hasUnitChatAccess)
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
              if (user.isAdmin)
                _HomeTile(
                  icon: Icons.security,
                  title: 'Panel admina',
                  subtitle: pendingCount > 0
                      ? 'Nowe konta: $pendingCount'
                      : 'Nowe konta do akceptacji: 0',
                  badgeCount: pendingCount,
                  onTap: () => context.push(RoutePaths.adminPanel),
                ),
              if (user.isModerator)
                _HomeTile(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Panel moderatora',
                  subtitle: 'Przydzielone uprawnienia moderacyjne',
                  onTap: () => context.push(RoutePaths.moderatorPanel),
                ),
              const SizedBox(height: 26),
              IgnorePointer(
                child: Opacity(
                  opacity: 0.1,
                  child: Center(
                    child: Image.asset(
                      'assets/images/logo_tbg112.png',
                      width: 210,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
          );
        },
      ),
    );
  }
}

class _StartUserCard extends StatelessWidget {
  const _StartUserCard({required this.user, required this.activeCount});

  final AppUser user;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    final fullName = user.fullName.trim().isEmpty
        ? user.displayName
        : user.fullName;
    final nickname = user.nickname.trim().isEmpty ? user.login : user.nickname;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        UserAvatar(user: user, radius: 48),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              fullName,
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '@$nickname',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 8),
        Text(
          '${user.role.label} • ${_serviceLine(user)}',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _InfoPill(
                color: _presenceColor(user.presenceStatus),
                text: user.presenceStatus.label,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoPill(
                color: AppColors.cyan,
                text: '👥 $activeCount aktywnych',
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _serviceLine(AppUser user) {
    if (user.unitType.name == 'informator' || user.unitType.name == 'media') {
      return user.unitType.label;
    }
    final unitName = user.unitName.trim();
    return unitName.isEmpty ? user.unitType.label : unitName;
  }

  static Color _presenceColor(PresenceStatus status) {
    return switch (status) {
      PresenceStatus.online => Colors.greenAccent,
      PresenceStatus.busy => AppColors.orange,
      PresenceStatus.invisible => AppColors.muted,
      PresenceStatus.unavailable => AppColors.muted,
      PresenceStatus.offline => AppColors.red,
      PresenceStatus.manual => AppColors.cyan,
    };
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
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
