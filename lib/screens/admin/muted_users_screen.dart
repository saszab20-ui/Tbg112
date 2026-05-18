import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tarnobrzeg112/admin/admin_actions.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
import 'package:tarnobrzeg112/utils/date_time_utils.dart';
import 'package:tarnobrzeg112/utils/error_utils.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/empty_state.dart';
import 'package:tarnobrzeg112/widgets/loading_shimmer.dart';
import 'package:tarnobrzeg112/widgets/user_avatar.dart';

class MutedUsersScreen extends ConsumerWidget {
  const MutedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(mutedUsersProvider);
    return AppScaffold(
      title: 'Wyciszeni użytkownicy',
      showBackButton: true,
      fallbackRoute: RoutePaths.adminPanel,
      body: users.when(
        loading: () => LoadingShimmer(
          timeoutTitle: 'Brak wyciszonych',
          timeoutMessage: 'Nie znaleziono wyciszonych użytkowników.',
          onRefresh: () => ref.invalidate(mutedUsersProvider),
        ),
        error: (error, _) => EmptyState(
          icon: Icons.cloud_off,
          title: 'Nie można pobrać listy',
          message: ErrorUtils.readable(error),
          actionLabel: 'Odśwież',
          onAction: () => ref.invalidate(mutedUsersProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.volume_up_outlined,
              title: 'Brak wyciszonych',
              message: 'Aktualnie nikt nie jest wyciszony.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final user = items[index];
              return Card(
                child: ListTile(
                  leading: UserAvatar(user: user, radius: 22),
                  title: Text(user.publicName),
                  subtitle: Text(
                    [
                      if (user.mutedBy.isNotEmpty) 'Wyciszył: ${user.mutedBy}',
                      if (user.mutedUntil != null)
                        'Do: ${DateTimeUtils.compactDate(user.mutedUntil!)}',
                      if (user.mutedReason.isNotEmpty)
                        'Powód: ${user.mutedReason}',
                    ].join('\n'),
                  ),
                  isThreeLine: true,
                  trailing: FilledButton(
                    onPressed: () => AdminActions.unmute(ref, context, user),
                    child: const Text('Odblokuj'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
