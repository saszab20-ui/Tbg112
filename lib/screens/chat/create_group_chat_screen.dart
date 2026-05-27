import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
import 'package:tarnobrzeg112/utils/error_utils.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/empty_state.dart';
import 'package:tarnobrzeg112/widgets/loading_shimmer.dart';

class CreateGroupChatScreen extends ConsumerStatefulWidget {
  const CreateGroupChatScreen({super.key});

  @override
  ConsumerState<CreateGroupChatScreen> createState() =>
      _CreateGroupChatScreenState();
}

class _CreateGroupChatScreenState extends ConsumerState<CreateGroupChatScreen> {
  final _name = TextEditingController();
  final _search = TextEditingController();
  final _selected = <String>{};
  bool _creating = false;

  @override
  void dispose() {
    _name.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(currentAppUserProvider).asData?.value;
    final users = ref.watch(activeUsersProvider);
    return AppScaffold(
      title: 'Utwórz czat grupowy',
      currentIndex: 2,
      showBackButton: true,
      fallbackRoute: RoutePaths.privateChats,
      body: current == null
          ? const EmptyState(
              icon: Icons.lock_outline,
              title: 'Brak sesji',
              message: 'Zaloguj się ponownie.',
            )
          : users.when(
              loading: () => LoadingShimmer(
                timeoutTitle: 'Brak użytkowników',
                timeoutMessage: 'Nie można załadować listy osób do grupy.',
                onRefresh: () => ref.invalidate(activeUsersProvider),
              ),
              error: (error, _) => EmptyState(
                icon: Icons.cloud_off,
                title: 'Nie można pobrać użytkowników',
                message: ErrorUtils.readable(error),
                actionLabel: 'Odśwież',
                onAction: () => ref.invalidate(activeUsersProvider),
              ),
              data: (items) => _content(current, items),
            ),
    );
  }

  Widget _content(AppUser current, List<AppUser> users) {
    final query = _search.text.trim().toLowerCase();
    final candidates = users.where((user) {
      if (user.uid == current.uid) return false;
      if (query.isEmpty) return true;
      final haystack = [
        user.publicName,
        user.login,
        user.unitName,
        user.unitType.label,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
    final selectedUsers =
        users.where((user) => _selected.contains(user.uid)).toList()
          ..sort((a, b) => a.publicName.compareTo(b.publicName));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(
            labelText: 'Nazwa czatu',
            hintText: 'np. Czat okolice',
            prefixIcon: Icon(Icons.groups_3_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Szukaj użytkowników',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        if (selectedUsers.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final user in selectedUsers)
                InputChip(
                  label: Text(user.publicName),
                  onDeleted: () => setState(() => _selected.remove(user.uid)),
                ),
            ],
          ),
        const SizedBox(height: 12),
        if (candidates.isEmpty)
          const EmptyState(
            icon: Icons.people_outline,
            title: 'Brak użytkowników',
            message:
                'Możesz utworzyć grupę tylko dla siebie i później dodać członków z ustawień czatu.',
          )
        else
          for (final user in candidates)
            Card(
              child: CheckboxListTile(
                value: _selected.contains(user.uid),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selected.add(user.uid);
                    } else {
                      _selected.remove(user.uid);
                    }
                  });
                },
                title: Text(user.publicName),
                subtitle: Text(
                  user.unitName.trim().isEmpty
                      ? user.role.label
                      : user.unitName,
                ),
              ),
            ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _creating ? null : () => _create(current, users),
          icon: _creating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add),
          label: const Text('Utwórz czat'),
        ),
      ],
    );
  }

  Future<void> _create(AppUser current, List<AppUser> users) async {
    setState(() => _creating = true);
    try {
      final participants = users
          .where((user) => _selected.contains(user.uid))
          .toList();
      final chatId = await ref
          .read(privateChatRepositoryProvider)
          .createGroupChat(
            owner: current,
            name: _name.text,
            participants: participants,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Grupa utworzona.')));
      context.go(RoutePaths.privateChat(chatId));
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Nie udało się utworzyć grupy: ${ErrorUtils.readable(error)}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }
}
