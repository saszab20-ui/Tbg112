import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:tarnobrzeg112/models/chat_message.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
import 'package:tarnobrzeg112/themes/app_colors.dart';
import 'package:tarnobrzeg112/utils/date_time_utils.dart';
import 'package:tarnobrzeg112/widgets/user_avatar.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/utils/error_utils.dart';

class MessageBubble extends ConsumerWidget {
  const MessageBubble({
    required this.message,
    required this.isMine,
    required this.canModerate,
    required this.isAdmin,
    required this.canRecall,
    required this.showAvatar,
    required this.currentUserId,
    required this.mentionUsers,
    required this.onReply,
    required this.onReact,
    required this.onEdit,
    required this.onPin,
    required this.onDelete,
    required this.onReport,
    super.key,
    this.accentColor = AppColors.red,
    this.messageStyle = 'rounded',
    this.interactionsEnabled = true,
    this.readStatusText,
  });

  final ChatMessage message;
  final bool isMine;
  final bool canModerate;
  final bool isAdmin;
  final bool canRecall;
  final bool showAvatar;
  final String currentUserId;
  final List<AppUser> mentionUsers;
  final VoidCallback onReply;
  final ValueChanged<String> onReact;
  final VoidCallback onEdit;
  final VoidCallback onPin;
  final VoidCallback onDelete;
  final ValueChanged<ReportReason> onReport;
  final Color accentColor;
  final String messageStyle;
  final bool interactionsEnabled;
  final String? readStatusText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deletedForAdmin = message.isDeleted && isAdmin;
    final bubbleColor = deletedForAdmin
        ? AppColors.orange
        : isMine
        ? accentColor
        : AppColors.panelAlt;
    final textColor = _foregroundFor(bubbleColor);
    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.74;
    final senderUser = _senderUser();
    return GestureDetector(
      onLongPress: interactionsEnabled ? () => _showMenu(context) : null,
      onHorizontalDragEnd: (_) {
        if (interactionsEnabled && !message.isDeleted) onReply();
      },
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          textDirection: isMine ? TextDirection.rtl : TextDirection.ltr,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: showAvatar
                  ? _SenderAvatar(
                      message: message,
                      user: senderUser,
                      enabled: interactionsEnabled,
                    )
                  : const SizedBox(width: 32),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxBubbleWidth.clamp(168.0, 460.0),
              ),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor.withValues(alpha: isMine ? 0.88 : 0.92),
                  borderRadius: BorderRadius.circular(_bubbleRadius()),
                  border: Border.all(
                    color: message.pinned || deletedForAdmin
                        ? AppColors.orange
                        : Colors.transparent,
                  ),
                ),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: textColor),
                  child: IconTheme.merge(
                    data: IconThemeData(color: textColor),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                message.senderDisplayName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateTimeUtils.chatTime(message.createdAt),
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        if (message.replyPreview != null &&
                            !message.isDeleted) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              message.replyPreview!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.muted),
                            ),
                          ),
                        ],
                        if (message.isDeleted) ...[
                          const SizedBox(height: 8),
                          if (isAdmin)
                            OutlinedButton.icon(
                              onPressed: () => _showDeletedPreview(context),
                              icon: const Icon(Icons.visibility_outlined),
                              label: const Text('Pokaż wiadomość'),
                            )
                          else if (isAdmin) ...[
                            const Text(
                              'WIADOMOŚĆ COFNIĘTA',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Cofnął: ${message.deletedBy ?? 'Brak danych'}',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                            if (message.deletedAt != null)
                              Text(
                                'Kiedy: ${DateTimeUtils.chatTime(message.deletedAt!)}',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            const SizedBox(height: 6),
                            Text(
                              message.adminVisibleText.trim().isEmpty
                                  ? 'Brak treści tekstowej.'
                                  : message.adminVisibleText,
                            ),
                            if (message
                                .originalAttachmentsForAdmin
                                .isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _AttachmentsList(
                                attachments:
                                    message.originalAttachmentsForAdmin,
                              ),
                            ],
                          ] else
                            const Text(
                              'Wiadomość cofnięta',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ] else ...[
                          if (message.text.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _MessageText(
                              text: message.text,
                              mentionUsers: mentionUsers,
                            ),
                            if (message.editedAt != null) ...[
                              const SizedBox(height: 3),
                              const Text(
                                '(edytowano)',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                          if (message.imageUrl != null &&
                              message.attachments.isEmpty) ...[
                            const SizedBox(height: 10),
                            _ImageAttachmentPreview(
                              imageUrl: message.imageUrl!,
                              fileName: message.fileName,
                            ),
                          ],
                          if (message.attachments.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _AttachmentsList(attachments: message.attachments),
                          ] else if (message.fileUrl != null) ...[
                            const SizedBox(height: 10),
                            if (message.mediaType == ChatMediaType.image)
                              _ImageAttachmentPreview(
                                imageUrl: message.fileUrl!,
                                fileName: message.fileName,
                              )
                            else if (message.mediaType == ChatMediaType.voice)
                              _VoiceAttachmentPlayer(
                                url: message.fileUrl!,
                                fileName: message.fileName ?? 'Głosówka',
                              )
                            else
                              _AttachmentRow(
                                mediaType: message.mediaType,
                                fileName: message.fileName ?? 'Plik',
                              ),
                          ],
                        ],
                        if (message.reactions.isNotEmpty &&
                            !message.isDeleted) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            children: message.reactions.entries
                                .where((entry) => entry.value.isNotEmpty)
                                .map((entry) {
                                  final reactedByMe = entry.value.contains(
                                    currentUserId,
                                  );
                                  return ActionChip(
                                    label: Text(
                                      '${entry.key} ${entry.value.length}',
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    side: BorderSide(
                                      color: reactedByMe
                                          ? AppColors.orange
                                          : AppColors.border,
                                    ),
                                    onPressed: () {
                                      if (reactedByMe) {
                                        _showReactionOptions(
                                          context,
                                          entry.key,
                                        );
                                      } else {
                                        onReact(entry.key);
                                      }
                                    },
                                  );
                                })
                                .toList(),
                          ),
                        ],
                        if (message.mentions.contains(currentUserId) &&
                            !message.isDeleted) ...[
                          const SizedBox(height: 8),
                          const Chip(
                            avatar: Icon(Icons.alternate_email, size: 16),
                            label: Text('@ oznaczono Cię'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                        if (isMine &&
                            readStatusText != null &&
                            readStatusText!.trim().isNotEmpty &&
                            !message.isDeleted) ...[
                          const SizedBox(height: 5),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              readStatusText!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textColor.withValues(alpha: 0.78),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  AppUser? _senderUser() {
    for (final user in mentionUsers) {
      if (user.uid == message.senderId) return user;
    }
    return null;
  }

  double _bubbleRadius() {
    return switch (messageStyle) {
      'compact' => 10,
      'soft' => 24,
      _ => 18,
    };
  }

  Color _foregroundFor(Color background) {
    return background.computeLuminance() > 0.55
        ? const Color(0xFF111827)
        : AppColors.white;
  }

  void _showDeletedPreview(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wiadomość cofnięta'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cofnął: ${message.deletedBy ?? 'Brak danych'}'),
              if (message.deletedAt != null)
                Text('Kiedy: ${DateTimeUtils.chatTime(message.deletedAt!)}'),
              const SizedBox(height: 12),
              Text(
                message.adminVisibleText.trim().isEmpty
                    ? 'Brak treści tekstowej.'
                    : message.adminVisibleText,
              ),
              if (message.originalAttachmentsForAdmin.isNotEmpty) ...[
                const SizedBox(height: 12),
                _AttachmentsList(
                  attachments: message.originalAttachmentsForAdmin,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zamknij'),
          ),
        ],
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.panel,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              if (!message.isDeleted)
                ListTile(
                  leading: const Icon(Icons.reply),
                  title: const Text('Odpowiedz'),
                  onTap: () {
                    Navigator.pop(context);
                    onReply();
                  },
                ),
              if (!message.isDeleted)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final emoji in _quickReactions)
                        ActionChip(
                          label: Text(
                            emoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            if (emoji == '➕') {
                              _showEmojiPicker(context);
                            } else {
                              onReact(emoji);
                            }
                          },
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.add_reaction_outlined),
                        label: const Text('Więcej'),
                        onPressed: () {
                          Navigator.pop(context);
                          _showEmojiPicker(context);
                        },
                      ),
                    ],
                  ),
                ),
              if (!message.isDeleted && isMine)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edytuj'),
                  onTap: () {
                    Navigator.pop(context);
                    onEdit();
                  },
                ),
              if (!message.isDeleted && message.text.trim().isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.copy_outlined),
                  title: const Text('Kopiuj'),
                  onTap: () {
                    Navigator.pop(context);
                    Clipboard.setData(ClipboardData(text: message.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Skopiowano wiadomość.')),
                    );
                  },
                ),
              if (isAdmin && message.editHistory.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Historia edycji'),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditHistory(context);
                  },
                ),
              if (canModerate && !message.isDeleted)
                ListTile(
                  leading: const Icon(Icons.push_pin),
                  title: const Text('Przypnij'),
                  onTap: () {
                    Navigator.pop(context);
                    onPin();
                  },
                ),
              if (canRecall && !message.isDeleted)
                ListTile(
                  leading: const Icon(Icons.undo),
                  title: const Text('Cofnij wiadomość'),
                  onTap: () {
                    Navigator.pop(context);
                    onDelete();
                  },
                ),
              if (!message.isDeleted)
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('Zgłoś'),
                  onTap: () {
                    Navigator.pop(context);
                    onReport(ReportReason.abuse);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showEmojiPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.panel,
      showDragHandle: true,
      builder: (context) => _EmojiPickerSheet(onSelected: onReact),
    );
  }

  void _showReactionOptions(BuildContext context, String emoji) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.panel,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.backspace_outlined),
              title: const Text('Usuń reakcję'),
              subtitle: Text(emoji),
              onTap: () {
                Navigator.pop(context);
                onReact(emoji);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_reaction_outlined),
              title: const Text('Zmień reakcję'),
              onTap: () {
                Navigator.pop(context);
                _showEmojiPicker(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditHistory(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Historia edycji'),
        content: SizedBox(
          width: 420,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: message.editHistory.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              final entry = message.editHistory[index];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.history),
                title: Text((entry['oldText'] as String?) ?? 'Brak tekstu'),
                subtitle: Text(
                  'Edytował: ${entry['editedByLogin'] ?? entry['editedBy'] ?? 'brak danych'}',
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zamknij'),
          ),
        ],
      ),
    );
  }
}

const _quickReactions = [
  '\u{1F44D}',
  '\u{2764}\u{FE0F}',
  '\u{1F602}',
  '\u{1F62E}',
  '\u{1F622}',
  '\u{1F621}',
  '\u{2795}',
];

class _SenderAvatar extends ConsumerWidget {
  const _SenderAvatar({
    required this.message,
    required this.user,
    required this.enabled,
  });

  final ChatMessage message;
  final AppUser? user;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = user;
    if (appUser != null) {
      return InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: enabled ? () => _showAvatarMenu(context, ref, appUser) : null,
        child: UserAvatar(user: appUser, radius: 18),
      );
    }
    final avatarUrl = message.senderAvatarUrl?.trim() ?? '';
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: enabled
          ? () => _showAvatarMenuForUnknown(context, ref, message.senderId)
          : null,
      child: Tooltip(
        message: message.senderDisplayName,
        child: ClipOval(
          child: Container(
            width: 36,
            height: 36,
            color: AppColors.panelAlt,
            alignment: Alignment.center,
            child: avatarUrl.isEmpty
                ? _InitialsText(message.senderDisplayName)
                : _SafeNetworkImage(
                    url: avatarUrl,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    fallback: _InitialsText(message.senderDisplayName),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAvatarMenu(
    BuildContext context,
    WidgetRef ref,
    AppUser other,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Zobacz profil'),
              onTap: () {
                Navigator.pop(context);
                context.push(RoutePaths.userProfile(other.uid));
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Prywatna rozmowa'),
              onTap: () async {
                try {
                  final current = ref
                      .read(currentAppUserProvider)
                      .asData
                      ?.value;
                  if (current == null) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Brak sesji.')),
                    );
                    return;
                  }
                  final chatId = await ref
                      .read(privateChatRepositoryProvider)
                      .openChat(current, other);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  context.go(RoutePaths.privateChat(chatId));
                } on Object catch (error) {
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Nie udało się utworzyć rozmowy: ${ErrorUtils.readable(error)}',
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAvatarMenuForUnknown(
    BuildContext context,
    WidgetRef ref,
    String uid,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Zobacz profil'),
              onTap: () {
                Navigator.pop(context);
                context.push(RoutePaths.userProfile(uid));
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Prywatna rozmowa'),
              onTap: () async {
                try {
                  final current = ref
                      .read(currentAppUserProvider)
                      .asData
                      ?.value;
                  if (current == null) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Brak sesji.')),
                    );
                    return;
                  }
                  final other = await ref
                      .read(usersRepositoryProvider)
                      .watchUser(uid)
                      .first;
                  if (!context.mounted) return;
                  if (other == null) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Nie znaleziono użytkownika.'),
                      ),
                    );
                    return;
                  }
                  final chatId = await ref
                      .read(privateChatRepositoryProvider)
                      .openChat(current, other);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  context.go(RoutePaths.privateChat(chatId));
                } on Object catch (error) {
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Nie udało się utworzyć rozmowy: ${ErrorUtils.readable(error)}',
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String value) {
    final clean = value.split('(').first.trim();
    final parts = clean.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    if (parts.isEmpty) return '112';
    final first = parts.first.characters.first;
    final last = parts.length > 1 ? parts.last.characters.first : '';
    return '$first$last'.toUpperCase();
  }
}

class _InitialsText extends StatelessWidget {
  const _InitialsText(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    return Text(
      _SenderAvatar._initials(name),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
    );
  }
}

class _SafeNetworkImage extends StatelessWidget {
  const _SafeNetworkImage({
    required this.url,
    required this.fallback,
    this.loading,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String url;
  final Widget fallback;
  final Widget? loading;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return fallback;
    if (kIsWeb) {
      return Image.network(
        cleanUrl,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: loading == null
            ? null
            : (context, child, progress) => progress == null ? child : loading!,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return CachedNetworkImage(
      imageUrl: cleanUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: loading == null ? null : (_, _) => loading!,
      errorWidget: (_, _, _) => fallback,
    );
  }
}

class _MessageText extends StatelessWidget {
  const _MessageText({required this.text, required this.mentionUsers});

  final String text;
  final List<AppUser> mentionUsers;

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'@[A-Za-z0-9_ąćęłńóśźżĄĆĘŁŃÓŚŹŻ.-]+');
    var cursor = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final token = text.substring(match.start + 1, match.end);
      final user = _findMentionUser(token);
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: const TextStyle(
            color: AppColors.cyan,
            fontWeight: FontWeight.w900,
          ),
          recognizer: user == null
              ? null
              : (TapGestureRecognizer()
                  ..onTap = () =>
                      context.push(RoutePaths.userProfile(user.uid))),
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    if (spans.isEmpty) return Text(text);
    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: spans,
      ),
    );
  }

  AppUser? _findMentionUser(String token) {
    final normalized = token.toLowerCase().replaceAll('_', ' ');
    for (final user in mentionUsers) {
      final nickname = user.nickname.toLowerCase();
      final login = user.login.toLowerCase();
      final compactNickname = nickname.replaceAll(RegExp(r'\s+'), ' ');
      final underscoredNickname = nickname.replaceAll(RegExp(r'\s+'), '_');
      if (normalized == compactNickname ||
          token.toLowerCase() == underscoredNickname ||
          token.toLowerCase() == login) {
        return user;
      }
    }
    return null;
  }
}

class _EmojiPickerSheet extends StatefulWidget {
  const _EmojiPickerSheet({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  State<_EmojiPickerSheet> createState() => _EmojiPickerSheetState();
}

class _EmojiPickerSheetState extends State<_EmojiPickerSheet> {
  static final List<String> _recent = [];
  final _search = TextEditingController();
  String _category = 'Popularne';
  static const _categories = <String, List<String>>{
    'Uśmiechy': [
      '\u{1F600}',
      '\u{1F603}',
      '\u{1F604}',
      '\u{1F601}',
      '\u{1F606}',
      '\u{1F642}',
      '\u{1F609}',
      '\u{1F60A}',
      '\u{1F917}',
      '\u{1F923}',
    ],
    'Emocje': [
      '\u{2764}\u{FE0F}',
      '\u{1F970}',
      '\u{1F49B}',
      '\u{1F49A}',
      '\u{1F499}',
      '\u{1F49C}',
      '\u{1F5A4}',
      '\u{1F494}',
      '\u{1F49E}',
      '\u{1F914}',
    ],
    'Gesty': [
      '\u{1F44D}',
      '\u{1F44E}',
      '\u{1F44F}',
      '\u{1F64C}',
      '\u{1F44A}',
      '\u{270C}\u{FE0F}',
      '\u{1F44B}',
      '\u{1F449}',
      '\u{261D}\u{FE0F}',
      '\u{270B}',
    ],
    'Popularne': [
      '\u{1F44D}',
      '\u{2764}\u{FE0F}',
      '\u{1F602}',
      '\u{1F62E}',
      '\u{1F622}',
      '\u{1F621}',
      '\u{1F525}',
      '\u{2705}',
      '\u{26A0}\u{FE0F}',
      '\u{1F6A8}',
    ],
    'Straż': [
      '\u{1F692}',
      '\u{1F9EF}',
      '\u{1F525}',
      '\u{1F6A8}',
      '\u{26D1}\u{FE0F}',
      '\u{1F9F0}',
      '\u{1F4A6}',
      '\u{1F687}\u{FE0F}',
      '\u{1F6E1}',
      '\u{26A0}\u{FE0F}',
    ],
    'Ratownictwo': [
      '\u{1F691}',
      '\u{1FA7A}',
      '\u{1F489}',
      '\u{1FA85}',
      '\u{2764}\u{FE0F}',
      '\u{26D1}\u{FE0F}',
      '\u{1FAF0}',
      '\u{1FAF1}',
      '\u{2705}',
      '\u{1F33E}',
    ],
    'Policja': [
      '\u{1F693}',
      '\u{1F46E}',
      '\u{1F694}',
      '\u{1F6A8}',
      '\u{2696}\u{FE0F}',
      '\u{1F6E1}\u{FE0F}',
      '\u{1F4D8}',
      '\u{1F526}',
      '\u{1F6A7}',
      '\u{2705}',
    ],
    'Wydarzenia': [
      '\u{1F389}',
      '\u{1F4C5}',
      '\u{1F4D8}',
      '\u{1F4DA}',
      '\u{2705}',
      '\u{1F6E7}',
      '\u{1F397}\u{FE0F}',
      '\u{1F44B}',
      '\u{1F57B}\u{FE0F}',
      '\u{1F4E4}',
    ],
    'Ostrzeżenia': [
      '\u{26A0}\u{FE0F}',
      '\u{1F6A8}',
      '\u{26D4}',
      '\u{1F6A7}',
      '\u{2757}',
      '\u{203C}\u{FE0F}',
      '\u{1F6D0}',
      '\u{1F6DE}\u{FE0F}',
      '\u{1F525}',
      '\u{1F9E0}',
    ],
    'Pogoda': [
      '\u{1F326}\u{FE0F}',
      '\u{1F327}\u{FE0F}',
      '\u{26C8}\u{FE0F}',
      '\u{1F328}\u{FE0F}',
      '\u{1F6DE}\u{FE0F}',
      '\u{1F32B}\u{FE0F}',
      '\u{2600}\u{FE0F}',
      '\u{1F699}',
      '\u{1F4A8}',
      '\u{1F9E0}',
    ],
    'Różne': [
      '\u{1F3E0}',
      '\u{1F4D8}',
      '\u{1F4E4}',
      '\u{1F517}',
      '\u{1F4AC}',
      '\u{1F4B7}',
      '\u{1F38A}',
      '\u{1F399}\u{FE0F}',
      '\u{1F4C1}',
      '\u{1F579}',
    ],
  };

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final source = _category == 'Ostatnie'
        ? _recent
        : _categories[_category] ?? _categories['Popularne']!;
    final emojis = query.isEmpty
        ? source
        : _categories.values
              .expand((items) => items)
              .where((emoji) => emoji.contains(query))
              .toSet()
              .toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.62,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  labelText: 'Szukaj emotki',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _categoryChip('Ostatnie'),
                  for (final name in _categories.keys) _categoryChip(name),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 56,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: emojis.length,
                itemBuilder: (context, index) {
                  final emoji = emojis[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      _recent
                        ..remove(emoji)
                        ..insert(0, emoji);
                      if (_recent.length > 24) _recent.removeLast();
                      widget.onSelected(emoji);
                      Navigator.pop(context);
                    },
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryChip(String name) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: _category == name,
        label: Text(name),
        onSelected: (_) => setState(() => _category = name),
      ),
    );
  }
}

class _AttachmentsList extends StatelessWidget {
  const _AttachmentsList({required this.attachments});

  final List<MessageAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final attachment in attachments)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: switch (attachment.mediaType) {
              ChatMediaType.image => _ImageAttachmentPreview(
                imageUrl: attachment.url,
                fileName: attachment.fileName,
              ),
              ChatMediaType.voice => _VoiceAttachmentPlayer(
                url: attachment.url,
                fileName: attachment.fileName ?? 'Głosówka',
              ),
              _ => _AttachmentRow(
                mediaType: attachment.mediaType,
                fileName: attachment.fileName ?? attachment.mediaType.label,
              ),
            },
          ),
      ],
    );
  }
}

class _ImageAttachmentPreview extends StatelessWidget {
  const _ImageAttachmentPreview({required this.imageUrl, this.fileName});

  final String imageUrl;
  final String? fileName;

  @override
  Widget build(BuildContext context) {
    final name = _safeDisplayName(fileName);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final previewWidth = (screenWidth < 430 ? screenWidth - 120 : 280.0)
        .clamp(150.0, 280.0)
        .toDouble();
    final previewHeight = previewWidth * 0.64;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _showImagePreview(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: previewWidth,
              height: previewHeight,
              child: _SafeNetworkImage(
                url: imageUrl,
                fit: BoxFit.cover,
                loading: Container(
                  color: Colors.black26,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
                fallback: const _AttachmentRow(
                  mediaType: ChatMediaType.image,
                  fileName: 'Nie można wyświetlić zdjęcia',
                ),
              ),
            ),
          ),
        ),
        if (name != null && name.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ],
    );
  }

  String? _safeDisplayName(String? value) {
    final clean = value?.trim() ?? '';
    if (clean.isEmpty) return null;
    if (clean.startsWith('scaled_') ||
        clean.startsWith('image_picker_') ||
        clean.length > 80 ||
        RegExp(r'^[a-f0-9-]{24,}\.').hasMatch(clean.toLowerCase())) {
      return null;
    }
    return clean;
  }

  void _showImagePreview(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 0.7,
                    maxScale: 4,
                    child: _SafeNetworkImage(
                      url: imageUrl,
                      fit: BoxFit.contain,
                      loading: const CircularProgressIndicator(),
                      fallback: const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white,
                        size: 56,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filled(
                    tooltip: 'Zamknij',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VoiceAttachmentPlayer extends StatefulWidget {
  const _VoiceAttachmentPlayer({required this.url, required this.fileName});

  final String url;
  final String fileName;

  @override
  State<_VoiceAttachmentPlayer> createState() => _VoiceAttachmentPlayerState();
}

class _VoiceAttachmentPlayerState extends State<_VoiceAttachmentPlayer> {
  late final AudioPlayer _player;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final loading =
            state?.processingState == ProcessingState.loading ||
            state?.processingState == ProcessingState.buffering;
        final playing = state?.playing ?? false;
        return Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: playing ? 'Pauza' : 'Odtwórz głosówkę',
                onPressed: loading ? null : _toggle,
                icon: loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(playing ? Icons.pause : Icons.play_arrow),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggle() async {
    if (_player.playing) {
      await _player.pause();
      return;
    }
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    if (_player.audioSource == null) {
      await _player.setUrl(widget.url);
    }
    await _player.play();
  }
}

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({required this.mediaType, required this.fileName});

  final ChatMediaType mediaType;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    final icon = switch (mediaType) {
      ChatMediaType.image => Icons.image_outlined,
      ChatMediaType.video => Icons.play_circle_outline,
      ChatMediaType.voice => Icons.graphic_eq,
      ChatMediaType.file || ChatMediaType.text => Icons.attach_file,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Flexible(child: Text(fileName, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
