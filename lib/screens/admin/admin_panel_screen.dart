import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    return AppScaffold(
      title: 'Panel admina',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassPanel(
            child: Row(
              children: [
                Badge(
                  isLabelVisible: pendingCount > 0,
                  label: Text('$pendingCount'),
                  child: const Icon(
                    Icons.person_add_alt,
                    color: AppColors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Nowe konta do akceptacji: $pendingCount',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Tile(
            icon: Icons.people_alt_outlined,
            title: 'Użytkownicy',
            subtitle: 'Akceptacje, role, bany i zawieszenia',
            badgeCount: pendingCount,
            onTap: () => context.go(RoutePaths.usersManagement),
          ),
          _Tile(
            icon: Icons.person_add_alt,
            title: 'Konta oczekujące',
            subtitle: 'Nowe konta do akceptacji: $pendingCount',
            badgeCount: pendingCount,
            onTap: () => context.go(RoutePaths.usersManagement),
          ),
          _Tile(
            icon: Icons.volume_off_outlined,
            title: 'Wyciszeni użytkownicy',
            subtitle: 'Lista wyciszeń, powody i odblokowanie',
            onTap: () => context.go(RoutePaths.mutedUsers),
          ),
          _Tile(
            icon: Icons.apartment_outlined,
            title: 'Jednostki',
            subtitle: 'Kanały jednostek i struktura dostępu',
            onTap: () => context.go(RoutePaths.unitsManagement),
          ),
          _Tile(
            icon: Icons.flag_outlined,
            title: 'Raporty',
            subtitle: 'Spam, nadużycia i podszywanie się',
            onTap: () => context.go(RoutePaths.reports),
          ),
          _Tile(
            icon: Icons.history,
            title: 'Logi administracyjne',
            subtitle: 'Działania adminów i moderatorów',
            onTap: () => context.go(RoutePaths.logs),
          ),
          _Tile(
            icon: Icons.forum_outlined,
            title: 'Czaty i grupy',
            subtitle: 'Czat główny, jednostki i wszystkie grupy użytkowników',
            onTap: () => context.go(RoutePaths.chats),
          ),
          _Tile(
            icon: Icons.manage_search,
            title: 'Cofnięte wiadomości',
            subtitle: 'Podgląd administracyjny oryginalnej treści',
            onTap: () => context.go(RoutePaths.deletedMessages),
          ),
        ],
      ),
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
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
