import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tarnobrzeg112/providers/admin_providers.dart';
import 'package:tarnobrzeg112/utils/date_time_utils.dart';
import 'package:tarnobrzeg112/utils/error_utils.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/empty_state.dart';
import 'package:tarnobrzeg112/widgets/loading_shimmer.dart';

class LogsScreen extends ConsumerWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(moderationLogsProvider);
    return AppScaffold(
      title: 'Logi administracyjne',
      body: logs.when(
        loading: () => LoadingShimmer(
          timeoutTitle: 'Brak logów',
          timeoutMessage: 'Nie ma jeszcze logów administracyjnych.',
          onRefresh: () => ref.invalidate(moderationLogsProvider),
        ),
        error: (error, _) => EmptyState(
          icon: Icons.cloud_off,
          title: 'Nie można pobrać logów',
          message: ErrorUtils.readable(error),
          actionLabel: 'Odśwież',
          onAction: () => ref.invalidate(moderationLogsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.history,
              title: 'Brak logów',
              message: 'Działania administracyjne zostaną zapisane tutaj.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final log = items[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(log.action),
                  subtitle: Text(
                    '${log.performedByLogin} • ${DateTimeUtils.compactDate(log.createdAt)}',
                  ),
                  trailing: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      '${log.oldValue ?? '-'} → ${log.newValue ?? '-'}',
                      overflow: TextOverflow.ellipsis,
                    ),
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
