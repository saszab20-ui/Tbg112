import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tarnobrzeg112/models/chat_message.dart';
import 'package:tarnobrzeg112/themes/app_colors.dart';

class MessageComposer extends StatefulWidget {
  const MessageComposer({
    required this.enabled,
    required this.onSend,
    super.key,
    this.replyTo,
    this.onCancelReply,
    this.disabledMessage,
  });

  final bool enabled;
  final ChatMessage? replyTo;
  final VoidCallback? onCancelReply;
  final String? disabledMessage;
  final Future<void> Function(
    String text,
    XFile? image,
    XFile? video,
    PlatformFile? voice,
    PlatformFile? file,
  )
  onSend;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final _controller = TextEditingController();
  final _imagePicker = ImagePicker();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.replyTo != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.panelAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.orange),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.reply, size: 18, color: AppColors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.replyTo!.userVisibleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onCancelReply,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            if (!widget.enabled && widget.disabledMessage != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.orange.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.volume_off_outlined,
                      size: 18,
                      color: AppColors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(widget.disabledMessage!)),
                  ],
                ),
              ),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 430;
                final tools = _ToolButtons(
                  enabled: widget.enabled && !_sending,
                  onImage: _pickImage,
                  onVideo: _pickVideo,
                  onVoice: _pickVoice,
                  onFile: _pickFile,
                );
                final input = Row(
                  children: [
                    Expanded(child: _messageField()),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: FilledButton(
                        onPressed: widget.enabled && !_sending
                            ? _sendText
                            : null,
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                      ),
                    ),
                  ],
                );
                if (compact) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(alignment: Alignment.centerLeft, child: tools),
                      const SizedBox(height: 8),
                      input,
                    ],
                  );
                }
                return Row(
                  children: [
                    tools,
                    const SizedBox(width: 8),
                    Expanded(child: input),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageField() {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: _controller,
        enabled: widget.enabled && !_sending,
        maxLines: 1,
        textInputAction: TextInputAction.send,
        onSubmitted: (_) {
          if (widget.enabled && !_sending) _sendText();
        },
        decoration: const InputDecoration(
          hintText: 'Wiadomość',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  Future<void> _sendText() async {
    await _send(_controller.text, null, null, null, null);
  }

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1800,
    );
    if (image == null) return;
    await _send(_controller.text, image, null, null, null);
  }

  Future<void> _pickVideo() async {
    final video = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (video == null) return;
    await _send(_controller.text, null, video, null, null);
  }

  Future<void> _pickVoice() async {
    final result = await FilePicker.pickFiles(
      type: FileType.audio,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    await _send(_controller.text, null, null, result.files.first, null);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    await _send(_controller.text, null, null, null, result.files.first);
  }

  Future<void> _send(
    String text,
    XFile? image,
    XFile? video,
    PlatformFile? voice,
    PlatformFile? file,
  ) async {
    setState(() => _sending = true);
    try {
      await widget.onSend(text, image, video, voice, file);
      _controller.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _ToolButtons extends StatelessWidget {
  const _ToolButtons({
    required this.enabled,
    required this.onImage,
    required this.onVideo,
    required this.onVoice,
    required this.onFile,
  });

  final bool enabled;
  final VoidCallback onImage;
  final VoidCallback onVideo;
  final VoidCallback onVoice;
  final VoidCallback onFile;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _IconTool(
          tooltip: 'Zdjęcie',
          icon: Icons.image_outlined,
          onPressed: enabled ? onImage : null,
        ),
        _IconTool(
          tooltip: 'Wideo',
          icon: Icons.videocam_outlined,
          onPressed: enabled ? onVideo : null,
        ),
        _IconTool(
          tooltip: 'Głosówka',
          icon: Icons.mic_none,
          onPressed: enabled ? onVoice : null,
        ),
        _IconTool(
          tooltip: 'Załącznik',
          icon: Icons.attach_file,
          onPressed: enabled ? onFile : null,
        ),
      ],
    );
  }
}

class _IconTool extends StatelessWidget {
  const _IconTool({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 40,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}
