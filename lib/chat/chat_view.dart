import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tarnobrzeg112/core/app_constants.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:tarnobrzeg112/models/chat_message.dart';
import 'package:tarnobrzeg112/models/pinned_message.dart';
import 'package:tarnobrzeg112/models/private_chat.dart';
import 'package:tarnobrzeg112/models/typing_user.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/providers/chat_providers.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';
import 'package:tarnobrzeg112/providers/settings_providers.dart';
import 'package:tarnobrzeg112/services/local_preferences.dart';
import 'package:tarnobrzeg112/themes/app_colors.dart';
import 'package:tarnobrzeg112/utils/date_time_utils.dart';
import 'package:tarnobrzeg112/utils/error_utils.dart';
import 'package:tarnobrzeg112/utils/text_utils.dart';
import 'package:tarnobrzeg112/widgets/empty_state.dart';
import 'package:tarnobrzeg112/widgets/loading_shimmer.dart';
import 'package:tarnobrzeg112/widgets/message_bubble.dart';
import 'package:tarnobrzeg112/widgets/message_composer.dart';

class ChatView extends ConsumerStatefulWidget {
  const ChatView({
    required this.scope,
    required this.chatId,
    this.readOnly = false,
    super.key,
  });

  final ChatScope scope;
  final String chatId;
  final bool readOnly;

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  ChatMessage? _replyTo;
  final _scrollController = ScrollController();
  int _messageLimit = AppConstants.messagesPageSize;
  bool _loadingOlder = false;
  bool _hasMore = true;
  String? _latestMessageId;
  String? _lastReadMarkKey;
  final _loadedHistoryNoticeKeys = <String>{};
  final _seenHistoryNoticeKeys = <String>{};
  final _visibleHistoryNoticeKeys = <String>{};

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
  void didUpdateWidget(covariant ChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope || oldWidget.chatId != widget.chatId) {
      _latestMessageId = null;
      _lastReadMarkKey = null;
      _messageLimit = AppConstants.messagesPageSize;
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ChatQuery(
      scope: widget.scope,
      chatId: widget.chatId,
      limit: _messageLimit,
    );
    final canonicalChatId = _canonicalChatId();
    final messages = ref.watch(chatMessagesProvider(query));
    final pinned = ref.watch(pinnedMessagesProvider(query)).asData?.value ?? [];
    final currentUser = ref.watch(currentAppUserProvider).asData?.value;
    final chat = ref.watch(privateChatProvider(canonicalChatId)).asData?.value;
    final personalizationKey = currentUser == null
        ? null
        : ChatPersonalizationKey(uid: currentUser.uid, chatId: canonicalChatId);
    final personalization = personalizationKey == null
        ? null
        : ref
              .watch(chatPersonalizationProvider(personalizationKey))
              .asData
              ?.value;
    final settings = _ResolvedChatSettings(chat, personalization);
    final accentColor = _colorFromHex(settings.themeColor) ?? AppColors.red;
    final mentionUsers =
        ref.watch(activeUsersProvider).asData?.value ?? const [];

    return _ChatThemeSurface(
      settings: settings,
      child: Column(
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
                message: ErrorUtils.chatLoad(error),
                actionLabel: 'Odśwież',
                onAction: () => ref.invalidate(chatMessagesProvider(query)),
              ),
              data: (items) {
                final clearedAt = currentUser == null
                    ? null
                    : chat?.clearedAt[currentUser.uid];
                final historyStartAt = _historyStartAt(currentUser, chat);
                final visibleItems = items
                    .where(
                      (message) =>
                          (clearedAt == null ||
                              message.createdAt.isAfter(clearedAt)) &&
                          (historyStartAt == null ||
                              !message.createdAt.isBefore(historyStartAt)) &&
                          (message.isDeleted ||
                              message.text.trim().isNotEmpty ||
                              message.hasAttachment) &&
                          (message.visibleTo.isEmpty ||
                              (currentUser != null &&
                                  message.visibleTo.contains(currentUser.uid))),
                    )
                    .toList();
                final showHistoryNotice = _shouldShowHistoryNotice(
                  canonicalChatId,
                  currentUser,
                  historyStartAt,
                );
                final renderItems = showHistoryNotice
                    ? [
                        ...visibleItems,
                        _historyNoticeMessage(
                          canonicalChatId,
                          historyStartAt ?? DateTime.now(),
                        ),
                      ]
                    : visibleItems;
                if (!widget.readOnly &&
                    currentUser != null &&
                    (widget.scope == ChatScope.private ||
                        widget.scope == ChatScope.group) &&
                    (chat?.unreadCount[currentUser.uid] ?? 0) > 0) {
                  _markPrivateRead(canonicalChatId, currentUser.uid);
                }
                if (!widget.readOnly) {
                  _markVisibleRead(
                    canonicalChatId: canonicalChatId,
                    currentUserId: currentUser?.uid,
                    latestMessageId: visibleItems.isEmpty
                        ? null
                        : visibleItems.first.id,
                  );
                }
                _maybeAutoScrollToLatest(visibleItems);
                if (visibleItems.isEmpty && !showHistoryNotice) {
                  return const EmptyState(
                    icon: Icons.forum_outlined,
                    title: 'Brak wiadomości',
                    message: 'Napisz pierwszą wiadomość.',
                  );
                }
                _hasMore = items.length >= _messageLimit;
                _ensureScrollablePagination(visibleItems.length);
                return ListView.builder(
                  key: PageStorageKey('chat-$canonicalChatId'),
                  controller: _scrollController,
                  reverse: true,
                  cacheExtent: 1400,
                  padding: const EdgeInsets.only(top: 12, bottom: 12),
                  addAutomaticKeepAlives: false,
                  addSemanticIndexes: false,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  itemCount: renderItems.length,
                  itemBuilder: (context, index) {
                    final message = renderItems[index];
                    if (message.senderId == 'system') {
                      return _SystemMessageTile(text: message.text);
                    }
                    final isMine = currentUser?.uid == message.senderId;
                    final showAvatar =
                        index == renderItems.length - 1 ||
                        renderItems[index + 1].senderId != message.senderId;
                    final canModerate =
                        !widget.readOnly && (currentUser?.isModerator ?? false);
                    final canRecall =
                        !widget.readOnly &&
                        (canModerate || currentUser?.uid == message.senderId);
                    return RepaintBoundary(
                      child: MessageBubble(
                        message: message,
                        isMine: isMine,
                        canModerate: canModerate,
                        isAdmin: currentUser?.isAdmin ?? false,
                        canRecall: canRecall,
                        showAvatar: showAvatar,
                        currentUserId: currentUser?.uid ?? '',
                        mentionUsers: mentionUsers,
                        accentColor: accentColor,
                        messageStyle: settings.messageStyle,
                        interactionsEnabled: !widget.readOnly,
                        readStatusText: _privateReadStatus(
                          message,
                          chat,
                          currentUser,
                        ),
                        onReply: () => setState(() => _replyTo = message),
                        onReact: (emoji) => _react(message, emoji),
                        onEdit: () => _edit(message),
                        onPin: () => _pin(message),
                        onDelete: () => _delete(message),
                        onReport: (reason) => _report(message, reason),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (currentUser != null && !widget.readOnly)
            _TypingIndicator(
              typingUsers: ref.watch(
                chatTypingProvider(
                  TypingQuery(
                    scope: widget.scope,
                    chatId: widget.chatId,
                    currentUserId: currentUser.uid,
                  ),
                ),
              ),
            ),

          MessageComposer(
            enabled: !widget.readOnly && (currentUser?.canWrite ?? false),
            disabledMessage: widget.readOnly
                ? 'Niewidzialny podgląd - pisanie jest wyłączone.'
                : currentUser?.isMuted == true
                ? 'Zostałeś wyciszony. Możesz czytać, ale nie możesz pisać.'
                : null,
            replyTo: _replyTo,
            onCancelReply: () => setState(() => _replyTo = null),
            onTypingChanged: currentUser == null ? null : _setTyping,
            mentionUsers: mentionUsers,
            onSend: _send,
          ),
        ],
      ),
    );
  }

  void _loadOlderIfNeeded() {
    if (!_scrollController.hasClients ||
        _messageLimit >= 500 ||
        _loadingOlder ||
        !_hasMore) {
      return;
    }
    final position = _scrollController.position;
    if (position.maxScrollExtent < 1) return;
    if (position.pixels > position.maxScrollExtent - 400) {
      _loadingOlder = true;
      setState(() => _messageLimit += AppConstants.messagesPageSize);
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _loadingOlder = false;
      });
    }
  }

  void _ensureScrollablePagination(int visibleCount) {
    if (visibleCount < _messageLimit ||
        _messageLimit >= 500 ||
        _loadingOlder ||
        !_hasMore) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_scrollController.hasClients ||
          _messageLimit >= 500 ||
          _loadingOlder ||
          !_hasMore) {
        return;
      }
      if (_scrollController.position.maxScrollExtent < 1) {
        _loadingOlder = true;
        setState(() => _messageLimit += AppConstants.messagesPageSize);
        Future<void>.delayed(const Duration(milliseconds: 350), () {
          if (mounted) _loadingOlder = false;
        });
      }
    });
  }

  void _maybeAutoScrollToLatest(List<ChatMessage> items) {
    final latestId = items.isEmpty ? null : items.first.id;
    final previousId = _latestMessageId;
    _latestMessageId = latestId;
    if (previousId == null || latestId == null || latestId == previousId) {
      return;
    }
    if (!_scrollController.hasClients ||
        _scrollController.position.pixels < 180) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToLatest();
      });
    }
  }

  String? _privateReadStatus(
    ChatMessage message,
    PrivateChat? chat,
    AppUser? currentUser,
  ) {
    if (widget.scope != ChatScope.private ||
        chat == null ||
        currentUser == null ||
        message.senderId != currentUser.uid ||
        message.senderId == 'system') {
      return null;
    }
    final readers = chat.participantIds.where((uid) => uid != currentUser.uid);
    for (final uid in readers) {
      final readAt = chat.readReceipts[uid];
      if (readAt != null && !readAt.isBefore(message.createdAt)) {
        return '✓✓ Odczytano ${DateTimeUtils.chatTime(readAt)}';
      }
    }
    for (final uid in readers) {
      final deliveredAt = chat.deliveredReceipts[uid];
      if (deliveredAt != null && !deliveredAt.isBefore(message.createdAt)) {
        return '✓✓ Dostarczono';
      }
    }
    return '✓ Wysłano';
  }

  Future<void> _send(
    String text,
    XFile? image,
    XFile? video,
    PlatformFile? voice,
    PlatformFile? file,
    List<String> mentionIds,
  ) async {
    final user = ref.read(currentAppUserProvider).asData?.value;
    if (user == null) return;
    try {
      unawaited(
        ref
            .read(usersRepositoryProvider)
            .updatePresence(user.uid, PresenceStatus.online),
      );
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
            mentionIds: mentionIds,
            replyTo: _replyTo,
          );
      setState(() => _replyTo = null);
      _scrollToLatest();
    } on Object catch (error, stackTrace) {
      debugPrint('CHAT SEND DEBUG error=$error');
      debugPrintStack(stackTrace: stackTrace);
      _showError(
        error,
        image:
            image != null ||
            (file != null && _isImageFileName(file.name, file.extension)),
      );
    }
  }

  Future<void> _setTyping(bool typing) async {
    final user = ref.read(currentAppUserProvider).asData?.value;
    if (user == null || !user.canWrite) return;
    try {
      if (typing) {
        unawaited(
          ref
              .read(usersRepositoryProvider)
              .updatePresence(user.uid, PresenceStatus.online),
        );
      }
      await ref
          .read(chatRepositoryProvider)
          .setTyping(
            scope: widget.scope,
            chatId: widget.chatId,
            user: user,
            typing: typing,
          );
    } on Object catch (error) {
      debugPrint('Typing status error: ${ErrorUtils.readable(error)}');
    }
  }

  void _markPrivateRead(String chatId, String uid) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(privateChatRepositoryProvider)
            .markRead(chatId, uid)
            .catchError((Object error) {
              debugPrint('PRIVATE READ MARK ERROR: $error');
            }),
      );
    });
  }

  void _markVisibleRead({
    required String canonicalChatId,
    required String? currentUserId,
    required String? latestMessageId,
  }) {
    if (currentUserId == null || latestMessageId == null) return;
    final key = '$canonicalChatId|$latestMessageId|$currentUserId';
    if (_lastReadMarkKey == key) return;
    _lastReadMarkKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await ref
            .read(notificationServiceProvider)
            .clearChatNotifications(canonicalChatId);
        await ref
            .read(chatRepositoryProvider)
            .markRead(
              scope: widget.scope,
              chatId: widget.chatId,
              uid: currentUserId,
              messageId: latestMessageId,
            );
      } on Object catch (error) {
        debugPrint('CHAT READ MARK ERROR: $error');
      }
    });
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

  Future<void> _edit(ChatMessage message) async {
    final user = ref.read(currentAppUserProvider).asData?.value;
    if (user == null) return;
    final controller = TextEditingController(text: message.text);
    final newText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edytuj wiadomość'),
        content: TextField(
          controller: controller,
          minLines: 1,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Treść wiadomości'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newText == null || newText.trim() == message.text.trim()) return;
    try {
      await ref
          .read(chatRepositoryProvider)
          .editMessage(
            scope: widget.scope,
            chatId: widget.chatId,
            message: message,
            actor: user,
            newText: newText,
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

  void _scrollToLatest() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  String _canonicalChatId() {
    if (widget.scope == ChatScope.global) return AppConstants.globalChatId;
    if (widget.scope == ChatScope.unit) {
      return TextUtils.unitChatId(widget.chatId);
    }
    return widget.chatId;
  }

  DateTime? _historyStartAt(AppUser? user, PrivateChat? chat) {
    if (user == null) return null;
    if (widget.scope == ChatScope.private || widget.scope == ChatScope.group) {
      return chat?.joinedAt[user.uid];
    }
    return user.joinedAt;
  }

  bool _shouldShowHistoryNotice(
    String chatId,
    AppUser? user,
    DateTime? historyStartAt,
  ) {
    if (user == null || historyStartAt == null) return false;
    final key = '${user.uid}|$chatId';
    if (_visibleHistoryNoticeKeys.contains(key)) return true;
    if (_seenHistoryNoticeKeys.contains(key)) return false;
    if (_loadedHistoryNoticeKeys.add(key)) {
      Future<void>(() async {
        final prefs = await loadLocalPreferences();
        final prefKey = 'chatHistoryNoticeSeen.$key';
        final seen = prefs.getBool(prefKey) ?? false;
        if (!mounted) return;
        setState(() {
          if (seen) {
            _seenHistoryNoticeKeys.add(key);
          } else {
            _visibleHistoryNoticeKeys.add(key);
          }
        });
        if (!seen) {
          await prefs.setBool(prefKey, true);
        }
      });
    }
    return false;
  }

  ChatMessage _historyNoticeMessage(String chatId, DateTime createdAt) {
    return ChatMessage(
      id: 'system_joined_$chatId',
      chatId: chatId,
      scope: widget.scope,
      senderId: 'system',
      senderLogin: 'system',
      senderDisplayName: 'System',
      senderUnitName: '',
      text: 'Dołączyłeś do czatu',
      createdAt: createdAt,
    );
  }

  Color? _colorFromHex(String? value) {
    final clean = value?.replaceFirst('#', '').trim();
    if (clean == null || clean.length != 6) return null;
    final parsed = int.tryParse('ff$clean', radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  bool _isImageFileName(String name, String? extension) {
    final ext = (extension ?? name.split('.').last).toLowerCase();
    return ext == 'jpg' || ext == 'jpeg' || ext == 'png' || ext == 'webp';
  }

  void _showError(Object error, {bool image = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ErrorUtils.chatSend(error, image: image))),
    );
  }
}

class _ResolvedChatSettings {
  _ResolvedChatSettings(this.chat, this.personalization);

  final PrivateChat? chat;
  final ChatPersonalizationSettings? personalization;

  String get themeColor {
    return _pick(personalization?.themeColor, chat?.themeColor, '#dc2626');
  }

  String get messageStyle {
    return _pick(personalization?.messageStyle, chat?.messageStyle, 'rounded');
  }

  String get backgroundType {
    return _pick(
      personalization?.backgroundType,
      chat?.backgroundType,
      'preset',
    );
  }

  String get backgroundImageUrl {
    return _pick(
      personalization?.backgroundImageUrl,
      chat?.backgroundImageUrl,
      '',
    );
  }

  String get backgroundPreset {
    return _pick(
      personalization?.backgroundPreset,
      chat?.backgroundPreset,
      'default',
    );
  }

  static String _pick(String? personal, String? shared, String fallback) {
    final cleanPersonal = personal?.trim() ?? '';
    if (cleanPersonal.isNotEmpty) return cleanPersonal;
    final cleanShared = shared?.trim() ?? '';
    if (cleanShared.isNotEmpty) return cleanShared;
    return fallback;
  }
}

class _ChatThemeSurface extends StatelessWidget {
  const _ChatThemeSurface({required this.settings, required this.child});

  final _ResolvedChatSettings settings;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(decoration: _decoration(), child: child);
  }

  BoxDecoration _decoration() {
    final imageUrl = settings.backgroundImageUrl.trim();
    if (settings.backgroundType == 'image' && imageUrl.isNotEmpty) {
      return BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        image: DecorationImage(
          image: kIsWeb
              ? NetworkImage(imageUrl)
              : CachedNetworkImageProvider(imageUrl),
          fit: BoxFit.cover,
          opacity: 0.22,
          onError: (_, _) {},
        ),
      );
    }
    final preset = settings.backgroundPreset;
    final colors = switch (preset) {
      'red-alert' => [AppColors.black, AppColors.red.withValues(alpha: 0.24)],
      'blue-service' => [
        AppColors.navy,
        AppColors.cyan.withValues(alpha: 0.16),
      ],
      'dark-grid' => [AppColors.black, AppColors.panel],
      'neon' => [const Color(0xFF111827), const Color(0xFF06B6D4)],
      'cosmos' => [const Color(0xFF020617), const Color(0xFF7C3AED)],
      'sunset' => [const Color(0xFF7F1D1D), const Color(0xFFF97316)],
      'premium' => [const Color(0xFF111827), const Color(0xFFD97706)],
      'waves' => [const Color(0xFF082F49), const Color(0xFF14B8A6)],
      'fire' => [const Color(0xFF1F0808), const Color(0xFFDC2626)],
      'police' => [const Color(0xFF020617), const Color(0xFF2563EB)],
      'rescue' => [const Color(0xFF052E16), const Color(0xFF16A34A)],
      _ => [Colors.transparent, Colors.transparent],
    };
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
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

class _SystemMessageTile extends StatelessWidget {
  const _SystemMessageTile({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.typingUsers});

  final AsyncValue<List<TypingUser>> typingUsers;

  @override
  Widget build(BuildContext context) {
    return typingUsers.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (users) {
        if (users.isEmpty) return const SizedBox.shrink();
        final names = users.take(2).map((user) => user.displayName).join(', ');
        final suffix = users.length == 1 ? 'pisze...' : 'pisz?...';
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
            child: Text(
              '$names $suffix',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        );
      },
    );
  }
}
