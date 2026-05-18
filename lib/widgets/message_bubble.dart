import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/models/chat_message.dart';
import 'package:tarnobrzeg112/themes/app_colors.dart';
import 'package:tarnobrzeg112/utils/date_time_utils.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    required this.isMine,
    required this.canModerate,
    required this.isAdmin,
    required this.canRecall,
    required this.onReply,
    required this.onReact,
    required this.onPin,
    required this.onDelete,
    required this.onReport,
    super.key,
  });

  final ChatMessage message;
  final bool isMine;
  final bool canModerate;
  final bool isAdmin;
  final bool canRecall;
  final VoidCallback onReply;
  final ValueChanged<String> onReact;
  final VoidCallback onPin;
  final VoidCallback onDelete;
  final ValueChanged<ReportReason> onReport;

  @override
  Widget build(BuildContext context) {
    final deletedForAdmin = message.isDeleted && isAdmin;
    final bubbleColor = deletedForAdmin
        ? AppColors.orange
        : isMine
        ? AppColors.red
        : AppColors.panelAlt;
    return GestureDetector(
      onLongPress: () => _showMenu(context),
      onHorizontalDragEnd: (_) {
        if (!message.isDeleted) onReply();
      },
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bubbleColor.withValues(alpha: isMine ? 0.88 : 0.92),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: message.pinned || deletedForAdmin
                    ? AppColors.orange
                    : AppColors.border,
              ),
            ),
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
                        style: const TextStyle(fontWeight: FontWeight.w900),
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
                if (message.replyPreview != null && !message.isDeleted) ...[
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
                  if (isAdmin) ...[
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
                    if (message.originalAttachmentsForAdmin.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _AttachmentsList(
                        attachments: message.originalAttachmentsForAdmin,
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
                    Text(message.text),
                  ],
                  if (message.imageUrl != null &&
                      message.attachments.isEmpty) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: message.imageUrl!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                  if (message.attachments.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _AttachmentsList(attachments: message.attachments),
                  ] else if (message.fileUrl != null) ...[
                    const SizedBox(height: 10),
                    _AttachmentRow(
                      mediaType: message.mediaType,
                      fileName: message.fileName ?? 'Plik',
                    ),
                  ],
                ],
                if (message.reactions.isNotEmpty && !message.isDeleted) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: message.reactions.entries
                        .where((entry) => entry.value.isNotEmpty)
                        .map(
                          (entry) => Chip(
                            label: Text('${entry.key} ${entry.value.length}'),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
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
                for (final emoji in const ['👍', '🔥', '🚒', '✅'])
                  ListTile(
                    leading: Text(emoji, style: const TextStyle(fontSize: 22)),
                    title: Text('Reakcja $emoji'),
                    onTap: () {
                      Navigator.pop(context);
                      onReact(emoji);
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
            child: attachment.mediaType == ChatMediaType.image
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: attachment.url,
                      fit: BoxFit.cover,
                    ),
                  )
                : _AttachmentRow(
                    mediaType: attachment.mediaType,
                    fileName: attachment.fileName ?? attachment.mediaType.label,
                  ),
          ),
      ],
    );
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
