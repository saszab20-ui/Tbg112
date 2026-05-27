import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/empty_state.dart';

class ModeratorPanelScreen extends ConsumerWidget {
  const ModeratorPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAppUserProvider).asData?.value;
    if (user == null || !user.isModerator) {
      return const AppScaffold(
        title: 'Panel moderatora',
        body: EmptyState(
          icon: Icons.lock_outline,
          title: 'Brak dostępu',
          message: 'Panel jest dostępny dla moderatorów i administratorów.',
        ),
      );
    }

    final tiles = _permissionTiles(user);
    return AppScaffold(
      title: 'Panel moderatora',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: tiles.isEmpty
            ? const [
                EmptyState(
                  icon: Icons.lock_outline,
                  title: 'Nie przydzielono dodatkowych uprawnień',
                  message:
                      'Administrator może włączyć wybrane funkcje moderatora.',
                ),
              ]
            : [
                for (final permission in tiles)
                  Card(
                    child: ListTile(
                      leading: Icon(permission.icon),
                      title: Text(permission.title),
                      subtitle: Text(permission.subtitle),
                      trailing: permission.route == null
                          ? const Icon(Icons.check_circle_outline)
                          : const Icon(Icons.chevron_right),
                      onTap: permission.route == null
                          ? null
                          : () => context.push(permission.route!),
                    ),
                  ),
              ],
      ),
    );
  }

  List<_ModeratorPermission> _permissionTiles(AppUser user) {
    return _moderatorPermissions
        .where(
          (permission) =>
              user.isAdmin || user.moderatorPermissions[permission.key] == true,
        )
        .toList();
  }
}

class _ModeratorPermission {
  const _ModeratorPermission({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.route,
  });

  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final String? route;
}

const _moderatorPermissions = [
  _ModeratorPermission(
    key: 'muteUsers',
    title: 'Wyciszanie użytkowników',
    subtitle: 'Wyciszanie i cofanie wyciszeń',
    icon: Icons.volume_off_outlined,
    route: RoutePaths.mutedUsers,
  ),
  _ModeratorPermission(
    key: 'manageEvents',
    title: 'Zarządzanie wydarzeniami',
    subtitle: 'Edycja i usuwanie wydarzeń',
    icon: Icons.event_outlined,
    route: RoutePaths.notifications,
  ),
  _ModeratorPermission(
    key: 'manageAnnouncements',
    title: 'Zarządzanie komunikatami',
    subtitle: 'Edycja i usuwanie komunikatów',
    icon: Icons.campaign_outlined,
    route: RoutePaths.notifications,
  ),
  _ModeratorPermission(
    key: 'accessLogs',
    title: 'Logi',
    subtitle: 'Podgląd logów administracyjnych',
    icon: Icons.history,
    route: RoutePaths.logs,
  ),
  _ModeratorPermission(
    key: 'manageReports',
    title: 'Raporty',
    subtitle: 'Obsługa zgłoszeń użytkowników',
    icon: Icons.flag_outlined,
    route: RoutePaths.reports,
  ),
  _ModeratorPermission(
    key: 'deleteMessages',
    title: 'Usuwanie wiadomości',
    subtitle: 'Cofanie nieodpowiednich wiadomości',
    icon: Icons.undo,
  ),
  _ModeratorPermission(
    key: 'editMessages',
    title: 'Edycja wiadomości',
    subtitle: 'Korekta wiadomości w moderowanych czatach',
    icon: Icons.edit_outlined,
  ),
  _ModeratorPermission(
    key: 'allowScreenshots',
    title: 'Zrzuty ekranu',
    subtitle: 'Administrator zezwolił na wykonywanie zrzutów',
    icon: Icons.screenshot_monitor_outlined,
  ),
  _ModeratorPermission(
    key: 'serviceUnitsAccess',
    title: 'Dostęp do jednostek',
    subtitle: 'Dostęp do dodatkowych jednostek nadany przez administratora',
    icon: Icons.apartment_outlined,
    route: RoutePaths.chats,
  ),
];
