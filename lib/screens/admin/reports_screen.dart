import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tarnobrzeg112/providers/admin_providers.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';
import 'package:tarnobrzeg112/utils/date_time_utils.dart';
import 'package:tarnobrzeg112/utils/error_utils.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/empty_state.dart';
import 'package:tarnobrzeg112/widgets/loading_shimmer.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportsProvider);
    final admin = ref.watch(currentAppUserProvider).asData?.value;
    return AppScaffold(
      title: 'Raporty',
      body: reports.when(
        loading: () => LoadingShimmer(
          timeoutTitle: 'Brak raportów',
          timeoutMessage: 'Nie ma obecnie raportów do moderacji.',
          onRefresh: () => ref.invalidate(reportsProvider),
        ),
        error: (error, _) => EmptyState(
          icon: Icons.cloud_off,
          title: 'Nie można pobrać raportów',
          message: ErrorUtils.readable(error),
          actionLabel: 'Odśwież',
          onAction: () => ref.invalidate(reportsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.flag_outlined,
              title: 'Brak raportow',
              message: 'Zgłoszenia użytkowników pojawią się tutaj.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final report = items[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(report.reason.label),
                  subtitle: Text(
                    '${report.status} • ${DateTimeUtils.compactDate(report.createdAt)}',
                  ),
                  trailing: report.status == 'resolved'
                      ? const Icon(Icons.done)
                      : TextButton(
                          onPressed: admin == null ||
                                  (!admin.isAdmin &&
                                      !admin.moderatorCan('manageReports'))
                              ? null
                              : () => ref
                                    .read(moderationRepositoryProvider)
                                    .resolveReport(
                                      reportId: report.id,
                                      admin: admin,
                                    ),
                          child: const Text('Zamknij'),
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
