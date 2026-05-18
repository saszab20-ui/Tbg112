import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tarnobrzeg112/models/notification_model.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';
import 'package:tarnobrzeg112/utils/error_utils.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/empty_state.dart';
import 'package:tarnobrzeg112/widgets/loading_shimmer.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAppUserProvider).asData?.value;
    if (user == null) {
      return const AppScaffold(
        title: 'Info',
        currentIndex: 3,
        body: EmptyState(
          icon: Icons.notifications_off_outlined,
          title: 'Brak sesji',
          message: 'Zaloguj się ponownie.',
        ),
      );
    }
    final notifications = ref
        .watch(notificationsRepositoryProvider)
        .watchForUser(user.uid);
    return AppScaffold(
      title: 'Info',
      currentIndex: 3,
      floatingActionButton: user.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showBroadcastDialog(context, ref),
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Komunikat'),
            )
          : null,
      body: StreamBuilder<List<NotificationModel>>(
        stream: notifications,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return LoadingShimmer(
              timeoutTitle: 'Brak komunikatów',
              timeoutMessage: 'Nie ma jeszcze komunikatów do wyświetlenia.',
              onRefresh: () => ref.invalidate(notificationsRepositoryProvider),
            );
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.cloud_off,
              title: 'Nie można pobrać komunikatów',
              message: ErrorUtils.readable(snapshot.error!),
              actionLabel: 'Odśwież',
              onAction: () => ref.invalidate(notificationsRepositoryProvider),
            );
          }
          final items = snapshot.data ?? const <NotificationModel>[];
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: 'Brak komunikatów',
              message: 'Nowe informacje pojawią się w tym miejscu.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final pinned = item.data['pinned'] == 'true';
              return Card(
                child: ListTile(
                  leading: Icon(
                    pinned
                        ? Icons.push_pin
                        : item.read
                        ? Icons.done
                        : Icons.circle,
                  ),
                  title: Text(item.title),
                  subtitle: Text(item.body),
                  trailing: Text(item.type.label),
                  onTap: item.recipientId == 'all'
                      ? null
                      : () => ref
                            .read(notificationsRepositoryProvider)
                            .markRead(item.id),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showBroadcastDialog(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final body = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Przypięty komunikat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Tytuł'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: body,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Treść'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () async {
              await ref
                  .read(notificationsRepositoryProvider)
                  .createBroadcast(title: title.text, body: body.text);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Dodaj'),
          ),
        ],
      ),
    );
    title.dispose();
    body.dispose();
  }
}
