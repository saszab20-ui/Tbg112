import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tarnobrzeg112/providers/chat_providers.dart';
import 'package:tarnobrzeg112/utils/error_utils.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/empty_state.dart';
import 'package:tarnobrzeg112/widgets/loading_shimmer.dart';
import 'package:tarnobrzeg112/widgets/message_bubble.dart';

class DeletedMessagesScreen extends ConsumerWidget {
  const DeletedMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(deletedMessagesProvider);
    return AppScaffold(
      title: 'Cofnięte wiadomości',
      body: messages.when(
        loading: () => LoadingShimmer(
          timeoutTitle: 'Brak cofniętych wiadomości',
          timeoutMessage: 'Nie ma obecnie cofniętych wiadomości do moderacji.',
          onRefresh: () => ref.invalidate(deletedMessagesProvider),
        ),
        error: (error, _) => EmptyState(
          icon: Icons.cloud_off,
          title: 'Nie można pobrać cofniętych wiadomości',
          message: ErrorUtils.readable(error),
          actionLabel: 'Odśwież',
          onAction: () => ref.invalidate(deletedMessagesProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.manage_search,
              title: 'Brak cofniętych wiadomości',
              message: 'Cofnięte wiadomości pojawią się tutaj.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final message = items[index];
              return MessageBubble(
                message: message,
                isMine: false,
                canModerate: false,
                isAdmin: true,
                canRecall: false,
                onReply: () {},
                onReact: (_) {},
                onPin: () {},
                onDelete: () {},
                onReport: (_) {},
              );
            },
          );
        },
      ),
    );
  }
}
