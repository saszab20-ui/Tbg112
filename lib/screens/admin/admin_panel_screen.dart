import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tarnobrzeg112/core/app_constants.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
import 'package:tarnobrzeg112/themes/app_colors.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/glass_panel.dart';

class AdminPanelScreen extends ConsumerWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingCount =
        ref.watch(pendingUsersProvider).asData?.value.length ?? 0;
    final stats = ref.watch(userStatsProvider).asData?.value;
    final user = ref.watch(currentAppUserProvider).asData?.value;
    return AppScaffold(
      title: 'Panel admina',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatsPanel(stats: stats, pendingCount: pendingCount),
          const SizedBox(height: 12),
          _Tile(
            icon: Icons.people_alt_outlined,
            title: 'Użytkownicy',
            subtitle: 'Akceptacje, role, bany i zawieszenia',
            badgeCount: pendingCount,
            onTap: () => context.push(RoutePaths.usersManagement),
          ),
          _Tile(
            icon: Icons.person_add_alt,
            title: 'Konta oczekujące',
            subtitle: 'Nowe konta do akceptacji: $pendingCount',
            badgeCount: pendingCount,
            onTap: () =>
                context.push('${RoutePaths.usersManagement}?filter=pending'),
          ),
          _Tile(
            icon: Icons.volume_off_outlined,
            title: 'Wyciszeni użytkownicy',
            subtitle: 'Lista wyciszeń, powody i odblokowanie',
            onTap: () => context.push(RoutePaths.mutedUsers),
          ),
          _Tile(
            icon: Icons.apartment_outlined,
            title: 'Jednostki',
            subtitle: 'Kanały jednostek i struktura dostępu',
            onTap: () => context.push(RoutePaths.unitsManagement),
          ),
          _Tile(
            icon: Icons.flag_outlined,
            title: 'Raporty',
            subtitle: 'Spam, nadużycia i podszywanie się',
            onTap: () => context.push(RoutePaths.reports),
          ),
          _Tile(
            icon: Icons.history,
            title: 'Logi administracyjne',
            subtitle: 'Działania adminów i moderatorów',
            onTap: () => context.push(RoutePaths.logs),
          ),
          _Tile(
            icon: Icons.forum_outlined,
            title: 'Czaty i grupy',
            subtitle: 'Czat główny, jednostki i wszystkie grupy użytkowników',
            onTap: () => context.push(RoutePaths.chats),
          ),
          _Tile(
            icon: Icons.manage_search,
            title: 'Cofnięte wiadomości',
            subtitle: 'Podgląd administracyjny oryginalnej treści',
            onTap: () => context.push(RoutePaths.deletedMessages),
          ),
          if (user?.isModerator == true)
            _Tile(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Panel moderatora',
              subtitle: 'Narzędzia moderacji dla uprawnionych użytkowników',
              onTap: () => context.push(RoutePaths.moderatorPanel),
            ),
          if (user?.isAdmin == true &&
              user?.login == AppConstants.superAdminLogin)
            _Tile(
              icon: Icons.visibility_outlined,
              title: 'Serwis / Podgląd techniczny',
              subtitle: '',
              onTap: () => context.push(RoutePaths.adminServiceMode),
            ),
        ],
      ),
    );
  }
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.stats, required this.pendingCount});

  final UserStats? stats;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final total = stats?.total ?? 0;
    final pending = stats?.pending ?? pendingCount;
    final active = stats?.active ?? 0;
    final blocked = stats?.blocked ?? 0;
    final muted = stats?.muted ?? 0;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Użytkownicy',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatChip(
                icon: Icons.groups_outlined,
                label: 'Wszyscy użytkownicy',
                value: total,
                onTap: () => context.push(RoutePaths.usersManagement),
              ),
              _StatChip(
                icon: Icons.hourglass_top,
                label: 'Do zatwierdzenia',
                value: pending,
                color: AppColors.orange,
                onTap: () => context.push(
                  '${RoutePaths.usersManagement}?filter=pending',
                ),
              ),
              _StatChip(
                icon: Icons.verified_outlined,
                label: 'Aktywni',
                value: active,
                color: AppColors.green,
                onTap: () =>
                    context.push('${RoutePaths.usersManagement}?filter=active'),
              ),
              _StatChip(
                icon: Icons.block,
                label: 'Zablokowani',
                value: blocked,
                color: AppColors.red,
                onTap: () => context.push(
                  '${RoutePaths.usersManagement}?filter=blocked',
                ),
              ),
              _StatChip(
                icon: Icons.volume_off_outlined,
                label: 'Wyciszeni',
                value: muted,
                color: AppColors.cyan,
                onTap: () => context.push(RoutePaths.mutedUsers),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.color = AppColors.white,
  });

  final IconData icon;
  final String label;
  final int value;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, color: color, size: 18),
      label: Text('$label: $value'),
      onPressed: onTap,
      side: BorderSide(color: color.withValues(alpha: 0.5)),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
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
            ? Badge(label: Text('$badgeCount'), child: Icon(icon))
            : Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: subtitle.trim().isEmpty ? null : Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
