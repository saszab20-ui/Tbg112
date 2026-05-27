import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/models/chat_message.dart';
import 'package:tarnobrzeg112/providers/chat_providers.dart';
import 'package:tarnobrzeg112/utils/error_utils.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/empty_state.dart';
import 'package:tarnobrzeg112/widgets/loading_shimmer.dart';
import 'package:tarnobrzeg112/widgets/message_bubble.dart';

class DeletedMessagesScreen extends ConsumerStatefulWidget {
  const DeletedMessagesScreen({super.key});

  @override
  ConsumerState<DeletedMessagesScreen> createState() =>
      _DeletedMessagesScreenState();
}

class _DeletedMessagesScreenState extends ConsumerState<DeletedMessagesScreen> {
  final _search = TextEditingController();
  ChatScope? _scopeFilter;
  int _visibleLimit = 30;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(deletedMessagesProvider);
    return AppScaffold(
      title: 'Cofnięte wiadomości',
      showBackButton: true,
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
        data: _content,
      ),
    );
  }

  Widget _content(List<ChatMessage> items) {
    final filtered = _filtered(items);
    final visible = filtered.take(_visibleLimit).toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        TextField(
          controller: _search,
          onChanged: (_) => setState(() => _visibleLimit = 30),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'Szukaj po treści, autorze lub czacie',
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              selected: _scopeFilter == null,
              label: const Text('Wszystkie'),
              onSelected: (_) => setState(() => _scopeFilter = null),
            ),
            for (final scope in ChatScope.values)
              ChoiceChip(
                selected: _scopeFilter == scope,
                label: Text(scope.wireName),
                onSelected: (_) => setState(() => _scopeFilter = scope),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          const EmptyState(
            icon: Icons.manage_search,
            title: 'Brak cofniętych wiadomości',
            message: 'Nie znaleziono wiadomości dla wybranych filtrów.',
          )
        else ...[
          Text(
            'Wyniki: ${filtered.length}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final message in visible)
            MessageBubble(
              message: message,
              isMine: false,
              canModerate: false,
              isAdmin: true,
              canRecall: false,
              showAvatar: true,
              currentUserId: '',
              mentionUsers: const [],
              onReply: () {},
              onReact: (_) {},
              onEdit: () {},
              onPin: () {},
              onDelete: () {},
              onReport: (_) {},
            ),
          if (visible.length < filtered.length)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _visibleLimit += 30),
                icon: const Icon(Icons.expand_more),
                label: const Text('Pokaż kolejne'),
              ),
            ),
        ],
      ],
    );
  }

  List<ChatMessage> _filtered(List<ChatMessage> items) {
    final query = _search.text.trim().toLowerCase();
    return items.where((message) {
      if (_scopeFilter != null && message.scope != _scopeFilter) return false;
      if (query.isEmpty) return true;
      final haystack = [
        message.senderDisplayName,
        message.senderLogin,
        message.chatId,
        message.adminVisibleText,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }
}
