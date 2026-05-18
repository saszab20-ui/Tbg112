import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    return AppScaffold(
      title: 'Panel moderatora',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.groups_2_outlined),
              title: Text('Moderuj ${user.unitName}'),
              subtitle: const Text('Usuwanie, wyciszanie i przypinanie'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(RoutePaths.unitChat(user.unitId)),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Raporty'),
              subtitle: const Text('Podgląd zgłoszeń do dalszej obsługi'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(RoutePaths.reports),
            ),
          ),
        ],
      ),
    );
  }
}
