import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tarnobrzeg112/core/app_constants.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/models/chat_message.dart';
import 'package:tarnobrzeg112/models/pinned_message.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/providers/chat_providers.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';
import 'package:tarnobrzeg112/utils/error_utils.dart';
import 'package:tarnobrzeg112/widgets/empty_state.dart';
import 'package:tarnobrzeg112/widgets/loading_shimmer.dart';
import 'package:tarnobrzeg112/widgets/message_bubble.dart';
import 'package:tarnobrzeg112/widgets/message_composer.dart';

class ChatView extends ConsumerStatefulWidget {
  const ChatView({required this.scope, required this.chatId, super.key});

  final ChatScope scope;
  final String chatId;

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  ChatMessage? _replyTo;
  final _scrollController = ScrollController();
  int _messageLimit = AppConstants.messagesPageSize;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadOlderIfNeeded);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ChatQuery(
      scope: widget.scope,
      chatId: widget.chatId,
      limit: _messageLimit,
    );
    final messages = ref.watch(chatMessagesProvider(query));
    final pinned = ref.watch(pinnedMessagesProvider(query)).asData?.value ?? [];
    final currentUser = ref.watch(currentAppUserProvider).asData?.value;

    return Column(
      children: [
        if (pinned.isNotEmpty) _PinnedStrip(messages: pinned),
        Expanded(
          child: messages.when(
            loading: () => LoadingShimmer(
              timeoutTitle: 'Nie znaleziono wiadomości',
              timeoutMessage:
                  'Jeśli czat jest pusty, możesz napisać pierwszą wiadomość.',
              onRefresh: () => ref.invalidate(chatMessagesProvider(query)),
            ),
            error: (error, _) => EmptyState(
              icon: Icons.cloud_off,
              title: 'Nie można pobrać czatu',
              message: ErrorUtils.readable(error),
              actionLabel: 'Odśwież',
              onAction: () => ref.invalidate(chatMessagesProvider(query)),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const EmptyState(
                  icon: Icons.forum_outlined,
                  title: 'Brak wiadomości',
                  message: 'Napisz pierwszą wiadomość.',
                );
              }
              return ListView.builder(
                controller: _scrollController,
                reverse: true,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final message = items[index];
                  final isMine = currentUser?.uid == message.senderId;
                  final canModerate = currentUser?.isModerator ?? false;
                  final canRecall =
                      canModerate || currentUser?.uid == message.senderId;
                  return MessageBubble(
                    message: message,
                    isMine: isMine,
                    canModerate: canModerate,
                    isAdmin: currentUser?.isAdmin ?? false,
                    canRecall: canRecall,
                    onReply: () => setState(() => _replyTo = message),
                    onReact: (emoji) => _react(message, emoji),
                    onPin: () => _pin(message),
                    onDelete: () => _delete(message),
                    onReport: (reason) => _report(message, reason),
                  );
                },
              );
            },
          ),
        ),
        MessageComposer(
          enabled: currentUser?.canWrite ?? false,
          disabledMessage: currentUser?.isMuted == true
              ? 'Zostałeś wyciszony. Możesz czytać, ale nie możesz pisać.'
              : null,
          replyTo: _replyTo,
          onCancelReply: () => setState(() => _replyTo = null),
          onSend: _send,
        ),
      ],
    );
  }

  void _loadOlderIfNeeded() {
    if (!_scrollController.hasClients || _messageLimit >= 500) return;
    final position = _scrollController.position;
    if (position.pixels > position.maxScrollExtent - 500) {
      setState(() => _messageLimit += AppConstants.messagesPageSize);
    }
  }

  Future<void> _send(
    String text,
    XFile? image,
    XFile? video,
    PlatformFile? voice,
    PlatformFile? file,
  ) async {
    final user = ref.read(currentAppUserProvider).asData?.value;
    if (user == null) return;
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            scope: widget.scope,
            chatId: widget.chatId,
            sender: user,
            text: text,
            image: image,
            video: video,
            voice: voice,
            file: file,
            replyTo: _replyTo,
          );
      setState(() => _replyTo = null);
    } on Object catch (error) {
      _showError(error);
    }
  }

  Future<void> _react(ChatMessage message, String emoji) async {
    final user = ref.read(currentAppUserProvider).asData?.value;
    if (user == null) return;
    final alreadyReacted =
        message.reactions[emoji]?.contains(user.uid) ?? false;
    try {
      await ref
          .read(chatRepositoryProvider)
          .toggleReaction(
            scope: widget.scope,
            chatId: widget.chatId,
            messageId: message.id,
            emoji: emoji,
            uid: user.uid,
            alreadyReacted: alreadyReacted,
          );
    } on Object catch (error) {
      _showError(error);
    }
  }

  Future<void> _pin(ChatMessage message) async {
    final user = ref.read(currentAppUserProvider).asData?.value;
    if (user == null) return;
    try {
      await ref
          .read(chatRepositoryProvider)
          .pinMessage(
            scope: widget.scope,
            chatId: widget.chatId,
            message: message,
            actor: user,
          );
    } on Object catch (error) {
      _showError(error);
    }
  }

  Future<void> _delete(ChatMessage message) async {
    final user = ref.read(currentAppUserProvider).asData?.value;
    if (user == null) return;
    try {
      await ref
          .read(chatRepositoryProvider)
          .deleteMessage(
            scope: widget.scope,
            chatId: widget.chatId,
            messageId: message.id,
            actor: user,
          );
    } on Object catch (error) {
      _showError(error);
    }
  }

  Future<void> _report(ChatMessage message, ReportReason reason) async {
    final user = ref.read(currentAppUserProvider).asData?.value;
    if (user == null) return;
    try {
      await ref
          .read(chatRepositoryProvider)
          .reportMessage(
            scope: widget.scope,
            chatId: widget.chatId,
            message: message,
            reporterId: user.uid,
            reason: reason,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zgłoszenie przekazane do moderacji.')),
      );
    } on Object catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Operacja nie powiodła się: ${ErrorUtils.readable(error)}',
        ),
      ),
    );
  }
}

class _PinnedStrip extends StatelessWidget {
  const _PinnedStrip({required this.messages});

  final List<PinnedMessage> messages;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black26,
      child: SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemBuilder: (context, index) => Chip(
            avatar: const Icon(Icons.push_pin, size: 16),
            label: Text(messages[index].text, overflow: TextOverflow.ellipsis),
          ),
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemCount: messages.length,
        ),
      ),
    );
  }
}
