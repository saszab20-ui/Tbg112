import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:tarnobrzeg112/models/private_chat.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/providers/chat_providers.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
import 'package:tarnobrzeg112/utils/error_utils.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/empty_state.dart';
import 'package:tarnobrzeg112/widgets/loading_shimmer.dart';
import 'package:tarnobrzeg112/widgets/user_avatar.dart';

class PrivateChatsScreen extends ConsumerStatefulWidget {
  const PrivateChatsScreen({super.key});

  @override
  ConsumerState<PrivateChatsScreen> createState() => _PrivateChatsScreenState();
}

class _PrivateChatsScreenState extends ConsumerState<PrivateChatsScreen> {
  final _search = TextEditingController();
  final _deliveredMarked = <String>{};

  @override
  void initState() {
    super.initState();
    _search.addListener(_refreshSearch);
  }

  @override
  void dispose() {
    _search
      ..removeListener(_refreshSearch)
      ..dispose();
    super.dispose();
  }

  void _refreshSearch() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentAppUserProvider).asData?.value;
    if (user == null) {
      return const AppScaffold(
        title: 'Prywatne',
        currentIndex: 2,
        body: EmptyState(
          icon: Icons.lock_outline,
          title: 'Brak sesji',
          message: 'Zaloguj się ponownie.',
        ),
      );
    }
    final chats = ref.watch(privateChatsProvider(user.uid));
    final activeUsers =
        ref.watch(activeUsersProvider).asData?.value ?? const <AppUser>[];
    return AppScaffold(
      title: 'Prywatne',
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
          final filtered = _filterChats(items, user.uid);
          _markDeliveredForVisible(user.uid, filtered);
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: filtered.isEmpty ? 2 : filtered.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) return _SearchField(controller: _search);
              if (filtered.isEmpty) {
                return EmptyState(
                  icon: Icons.lock_outline,
                  title: _search.text.trim().isEmpty
                      ? 'Brak rozmów'
                      : 'Brak wyników',
                  message: _search.text.trim().isEmpty
                      ? 'Rozpocznij rozmowę prywatną albo utwórz grupę.'
                      : 'Nie znaleziono rozmowy ani grupy dla wpisanej frazy.',
                );
              }
              final chat = filtered[index - 1];
              final otherUser = _otherParticipant(
                chat: chat,
                currentUid: user.uid,
                users: activeUsers,
              );
              return Card(
                child: ListTile(
                  leading: chat.isGroup || otherUser == null
                      ? CircleAvatar(
                          child: Icon(
                            chat.isGroup ? Icons.groups_3 : Icons.person,
                          ),
                        )
                      : UserAvatar(user: otherUser, radius: 22),
                  title: Text(chat.displayNameFor(user.uid)),
                  subtitle: Text(
                    chat.lastMessage.isEmpty
                        ? chat.isGroup
                              ? 'Grupa użytkowników'
                              : 'Brak wiadomości'
                        : chat.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Unread(count: chat.unreadCount[user.uid] ?? 0),
                      _ChatMenu(chat: chat, user: user),
                    ],
                  ),
                  onTap: () => context.go(RoutePaths.privateChat(chat.id)),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _markDeliveredForVisible(String uid, List<PrivateChat> chats) {
    final unreadChats = chats.where(
      (chat) => (chat.unreadCount[uid] ?? 0) > 0 && chat.chatKind == 'private',
    );
    for (final chat in unreadChats) {
      final key =
          '${chat.id}|$uid|${chat.lastMessageAt?.millisecondsSinceEpoch ?? 0}';
      if (!_deliveredMarked.add(key)) continue;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(privateChatRepositoryProvider)
            .markDelivered(chat.id, uid)
            .catchError((Object error) {
              debugPrint('PRIVATE DELIVERED MARK ERROR: $error');
            });
      });
    }
  }

  List<PrivateChat> _filterChats(List<PrivateChat> chats, String currentUid) {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return chats;
    return chats.where((chat) {
      final name = chat.displayNameFor(currentUid).toLowerCase();
      final lastMessage = chat.lastMessage.toLowerCase();
      final members = chat.participantNames.values.join(' ').toLowerCase();
      return name.contains(query) ||
          lastMessage.contains(query) ||
          members.contains(query);
    }).toList();
  }

  AppUser? _otherParticipant({
    required PrivateChat chat,
    required String currentUid,
    required List<AppUser> users,
  }) {
    if (chat.isGroup) return null;
    final otherId = chat.participantIds.firstWhere(
      (uid) => uid != currentUid,
      orElse: () => '',
    );
    if (otherId.isEmpty) return null;
    for (final user in users) {
      if (user.uid == otherId) return user;
    }
    return null;
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
                context.push(RoutePaths.createGroupChat);
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

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: const InputDecoration(
          labelText: 'Szukaj rozmów i grup',
          prefixIcon: Icon(Icons.search),
        ),
      ),
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
      leading: UserAvatar(user: other, radius: 22),
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

class _ChatMenu extends ConsumerWidget {
  const _ChatMenu({required this.chat, required this.user});

  final PrivateChat chat;
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_ChatAction>(
      tooltip: 'Opcje rozmowy',
      onSelected: (action) => _handle(context, ref, action),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _ChatAction.clear,
          child: Text('Wyczyść historię'),
        ),
        const PopupMenuItem(
          value: _ChatAction.unlimited,
          child: Text('Widoczność: bez limitu'),
        ),
        const PopupMenuItem(
          value: _ChatAction.twentyFourHours,
          child: Text('Widoczność: 24h'),
        ),
        if (chat.isGroup && chat.ownerId != user.uid)
          const PopupMenuItem(
            value: _ChatAction.leave,
            child: Text('Opuść grupę'),
          ),
        if (chat.isGroup && (chat.ownerId == user.uid || user.isAdmin))
          const PopupMenuItem(
            value: _ChatAction.deleteGroup,
            child: Text('Usuń grupę'),
          ),
        if (!chat.isGroup)
          const PopupMenuItem(
            value: _ChatAction.hide,
            child: Text('Usuń rozmowę z listy'),
          ),
      ],
    );
  }

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    _ChatAction action,
  ) async {
    final confirmed = await _confirm(context, action);
    if (!confirmed || !context.mounted) return;
    try {
      final repository = ref.read(privateChatRepositoryProvider);
      switch (action) {
        case _ChatAction.clear:
          await repository.clearHistoryForUser(chat: chat, user: user);
          break;
        case _ChatAction.leave:
          await repository.leaveGroup(chat: chat, user: user);
          break;
        case _ChatAction.deleteGroup:
          await repository.archiveGroup(chat: chat, actor: user);
          break;
        case _ChatAction.hide:
          await repository.hideChatForUser(chat: chat, user: user);
          break;
        case _ChatAction.unlimited:
          await repository.updateVisibilityMode(
            chat: chat,
            actor: user,
            visibilityMode: 'unlimited',
          );
          break;
        case _ChatAction.twentyFourHours:
          await repository.updateVisibilityMode(
            chat: chat,
            actor: user,
            visibilityMode: '24h',
          );
          break;
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Zapisano zmiany rozmowy.')));
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ErrorUtils.readable(error))));
    }
  }

  Future<bool> _confirm(BuildContext context, _ChatAction action) async {
    final title = switch (action) {
      _ChatAction.clear => 'Wyczyścić historię?',
      _ChatAction.leave => 'Opuścić grupę?',
      _ChatAction.deleteGroup => 'Usunąć grupę?',
      _ChatAction.hide => 'Usunąć rozmowę z listy?',
      _ChatAction.unlimited => 'Ustawić rozmowę bez limitu?',
      _ChatAction.twentyFourHours => 'Ustawić rozmowę na 24h?',
    };
    final message = switch (action) {
      _ChatAction.clear =>
        'Starsze wiadomości zostaną ukryte tylko dla Ciebie.',
      _ChatAction.leave => 'Nie będziesz już widzieć tej grupy.',
      _ChatAction.deleteGroup =>
        'Grupa zostanie zarchiwizowana dla uczestników.',
      _ChatAction.hide => 'Rozmowa zniknie z Twojej listy.',
      _ChatAction.unlimited => 'Rozmowa pozostanie bez limitu czasu.',
      _ChatAction.twentyFourHours =>
        'Po 24 godzinach rozmowa zniknie z listy uczestników.',
    };
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Anuluj'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Potwierdź'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

enum _ChatAction { clear, leave, deleteGroup, hide, unlimited, twentyFourHours }

class _Unread extends StatelessWidget {
  const _Unread({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Badge(label: Text(count > 99 ? '99+' : '$count'));
  }
}
