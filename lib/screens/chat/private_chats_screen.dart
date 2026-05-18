import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/providers/chat_providers.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
import 'package:tarnobrzeg112/utils/error_utils.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/empty_state.dart';
import 'package:tarnobrzeg112/widgets/loading_shimmer.dart';

class PrivateChatsScreen extends ConsumerWidget {
  const PrivateChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAppUserProvider).asData?.value;
    if (user == null) {
      return const AppScaffold(
        title: 'Prywatne i grupy',
        currentIndex: 2,
        body: EmptyState(
          icon: Icons.lock_outline,
          title: 'Brak sesji',
          message: 'Zaloguj się ponownie.',
        ),
      );
    }
    final chats = ref.watch(privateChatsProvider(user.uid));
    return AppScaffold(
      title: 'Prywatne i grupy',
      currentIndex: 2,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateMenu(context),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Nowa rozmowa'),
      ),
      body: chats.when(
        loading: () => LoadingShimmer(
          timeoutTitle: 'Brak rozmów',
          timeoutMessage: 'Nie znaleziono rozmów prywatnych ani grup.',
          onRefresh: () => ref.invalidate(privateChatsProvider(user.uid)),
        ),
        error: (error, _) => EmptyState(
          icon: Icons.cloud_off,
          title: 'Nie można pobrać rozmów',
          message: ErrorUtils.readable(error),
          actionLabel: 'Odśwież',
          onAction: () => ref.invalidate(privateChatsProvider(user.uid)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.lock_outline,
              title: 'Brak czatów',
              message: 'Rozpocznij rozmowę prywatną albo utwórz grupę.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final chat = items[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(chat.isGroup ? Icons.groups_3 : Icons.person),
                  ),
                  title: Text(chat.displayNameFor(user.uid)),
                  subtitle: Text(
                    chat.lastMessage.isEmpty
                        ? chat.isGroup
                              ? 'Czat grupowy'
                              : 'Brak wiadomości'
                        : chat.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: _Unread(count: chat.unreadCount[user.uid] ?? 0),
                  onTap: () => context.go(RoutePaths.privateChat(chat.id)),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showCreateMenu(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.person_add_alt),
              title: const Text('Rozmowa prywatna 1:1'),
              onTap: () {
                Navigator.pop(context);
                _showStartPrivateChat(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add_outlined),
              title: const Text('Utwórz czat grupowy'),
              onTap: () {
                Navigator.pop(context);
                context.go(RoutePaths.createGroupChat);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showStartPrivateChat(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _StartPrivateChatSheet(),
    );
  }
}

class _StartPrivateChatSheet extends ConsumerWidget {
  const _StartPrivateChatSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentAppUserProvider).asData?.value;
    final users = ref.watch(activeUsersProvider);
    return SafeArea(
      child: users.when(
        loading: () => const SizedBox(height: 180, child: LoadingShimmer()),
        error: (error, _) => EmptyState(
          icon: Icons.cloud_off,
          title: 'Nie można pobrać użytkowników',
          message: ErrorUtils.readable(error),
          actionLabel: 'Odśwież',
          onAction: () => ref.invalidate(activeUsersProvider),
        ),
        data: (items) {
          if (current == null) {
            return const EmptyState(
              icon: Icons.lock_outline,
              title: 'Brak sesji',
              message: 'Zaloguj się ponownie.',
            );
          }
          final candidates = items
              .where((candidate) => candidate.uid != current.uid)
              .toList();
          if (candidates.isEmpty) {
            return const EmptyState(
              icon: Icons.people_outline,
              title: 'Brak aktywnych użytkowników',
              message: 'Po akceptacji kont pojawią się tutaj osoby do rozmowy.',
            );
          }
          return ListView(
            shrinkWrap: true,
            children: [
              for (final other in candidates)
                _PrivateUserTile(current: current, other: other),
            ],
          );
        },
      ),
    );
  }
}

class _PrivateUserTile extends ConsumerWidget {
  const _PrivateUserTile({required this.current, required this.other});

  final AppUser current;
  final AppUser other;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person)),
      title: Text(other.publicName),
      subtitle: Text(other.role.label),
      onTap: () async {
        try {
          final chatId = await ref
              .read(privateChatRepositoryProvider)
              .openChat(current, other);
          if (context.mounted) {
            Navigator.pop(context);
            context.go(RoutePaths.privateChat(chatId));
          }
        } on Object catch (error) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Nie udało się utworzyć rozmowy: ${ErrorUtils.readable(error)}',
              ),
            ),
          );
        }
      },
    );
  }
}

class _Unread extends StatelessWidget {
  const _Unread({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Badge(label: Text('$count'));
  }
}
