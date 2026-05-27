import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
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
    this.onTypingChanged,
    this.mentionUsers = const [],
  });

  final bool enabled;
  final ChatMessage? replyTo;
  final VoidCallback? onCancelReply;
  final String? disabledMessage;
  final ValueChanged<bool>? onTypingChanged;
  final List<AppUser> mentionUsers;
  final Future<void> Function(
    String text,
    XFile? image,
    XFile? video,
    PlatformFile? voice,
    PlatformFile? file,
    List<String> mentionIds,
  )
  onSend;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final _controller = TextEditingController();
  final _imagePicker = ImagePicker();
  AudioRecorder? _audioRecorder;
  AudioPlayer? _voicePreviewPlayer;
  Timer? _typingTimer;
  bool _sending = false;
  bool _typing = false;
  bool _recording = false;
  DateTime? _recordingStartedAt;
  Timer? _recordingTicker;
  Duration _recordingElapsed = Duration.zero;
  PlatformFile? _pendingVoice;
  String? _pendingVoicePath;
  final Map<String, String> _selectedMentions = {};

  bool get _hasText => _controller.text.trim().isNotEmpty;
  bool get _canSendText => widget.enabled && !_sending && _hasText;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    unawaited(_recoverLostPickerData());
  }

  @override
  void didUpdateWidget(covariant MessageComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _typing) {
      _setTyping(false);
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _recordingTicker?.cancel();
    _setTyping(false);
    _controller
      ..removeListener(_onTextChanged)
      ..dispose();
    _audioRecorder?.dispose();
    _voicePreviewPlayer?.dispose();
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
            if (_mentionSuggestions().isNotEmpty)
              _MentionSuggestions(
                users: _mentionSuggestions(),
                onSelected: _insertMention,
              ),
            if (_pendingVoice != null)
              _VoicePreviewActions(
                sending: _sending,
                onPlay: _playPendingVoice,
                onSend: _sendPendingVoice,
                onCancel: _cancelPendingVoice,
              ),
            if (_recording)
              _RecordingBanner(
                elapsed: _recordingElapsed,
                onStop: _toggleVoiceRecording,
              ),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 430;
                final tools = _ToolButtons(
                  enabled: widget.enabled && !_sending,
                  recording: _recording,
                  onImage: _pickImage,
                  onCamera: _takePhoto,
                  onVideo: _pickVideo,
                  onVoice: kIsWeb ? null : _toggleVoiceRecording,
                  onFile: _pickFile,
                );
                final input = Row(
                  children: [
                    Expanded(child: _messageField()),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 48,
                      height: 52,
                      child: FilledButton(
                        onPressed: _canSendText ? _sendText : null,
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52, maxHeight: 180),
      child: TextField(
        controller: _controller,
        enabled: widget.enabled && !_sending,
        minLines: 1,
        maxLines: 8,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        textCapitalization: TextCapitalization.sentences,
        scrollPadding: const EdgeInsets.only(bottom: 120),
        decoration: const InputDecoration(
          hintText: 'Wiadomość',
          isDense: false,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        ),
      ),
    );
  }

  Future<void> _sendText() async {
    await _send(_controller.text, null, null, null, null);
  }

  Future<void> _pickImage() async {
    await _pickAndSendImage(ImageSource.gallery);
  }

  Future<void> _takePhoto() async {
    await _pickAndSendImage(ImageSource.camera);
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1800,
        maxHeight: 1800,
      );
      if (!mounted || image == null) return;
      await _send(_controller.text, image, null, null, null);
    } on Object catch (error) {
      _showSnack('Nie udało się dodać zdjęcia.');
      debugPrint('IMAGE PICK ERROR: $error');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final video = await _imagePicker.pickVideo(source: ImageSource.gallery);
      if (!mounted || video == null) return;
      await _send(_controller.text, null, video, null, null);
    } on Object catch (error) {
      _showSnack('Nie udało się dodać wideo.');
      debugPrint('VIDEO PICK ERROR: $error');
    }
  }

  Future<void> _recoverLostPickerData() async {
    if (kIsWeb) return;
    try {
      final response = await _imagePicker.retrieveLostData();
      if (!mounted || response.isEmpty) return;
      if (response.exception != null) {
        debugPrint('IMAGE PICK LOST DATA ERROR: ${response.exception}');
        return;
      }
      final file = response.file ?? response.files?.firstOrNull;
      if (file == null) return;
      if (response.type == RetrieveType.video) {
        await _send(_controller.text, null, file, null, null);
      } else {
        await _send(_controller.text, file, null, null, null);
      }
    } on Object catch (error) {
      debugPrint('IMAGE PICK LOST DATA RECOVERY ERROR: $error');
    }
  }

  Future<void> _toggleVoiceRecording() async {
    if (kIsWeb) {
      _showSnack('Głosówki dostępne tylko w aplikacji Android.');
      return;
    }
    if (_recording) {
      await _stopVoiceRecording();
      return;
    }
    await _startVoiceRecording();
  }

  Future<void> _startVoiceRecording() async {
    try {
      final recorder = _audioRecorder ??= AudioRecorder();
      final allowed = await recorder.hasPermission();
      if (!allowed) {
        _showSnack('Brak zgody na użycie mikrofonu.');
        return;
      }
      final tempDirectory = await getTemporaryDirectory();
      final path =
          '${tempDirectory.path}/tbg112_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );
      _recordingStartedAt = DateTime.now();
      _recordingTicker?.cancel();
      _recordingTicker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!mounted || _recordingStartedAt == null) return;
        setState(() {
          _recordingElapsed = DateTime.now().difference(_recordingStartedAt!);
        });
      });
      if (mounted) {
        setState(() {
          _recording = true;
          _recordingElapsed = Duration.zero;
        });
      }
      _showSnack(
        'Nagrywanie rozpoczęte. Kliknij mikrofon ponownie, aby wysłać.',
      );
    } on Object catch (error) {
      _showSnack('Nie udało się rozpocząć nagrywania: $error');
    }
  }

  Future<void> _stopVoiceRecording() async {
    try {
      final path = await _audioRecorder?.stop();
      _recordingTicker?.cancel();
      _recordingStartedAt = null;
      if (mounted) setState(() => _recording = false);
      if (path == null) {
        _showSnack('Nie udało się zapisać głosówki.');
        return;
      }
      final audio = XFile(path, mimeType: 'audio/mp4');
      final bytes = await audio.readAsBytes();
      if (bytes.isEmpty) {
        _showSnack('Głosówka jest pusta.');
        return;
      }
      final voice = PlatformFile(
        name: 'glosowka_${DateTime.now().millisecondsSinceEpoch}.m4a',
        size: bytes.length,
        bytes: bytes,
        path: path,
      );
      if (mounted) {
        setState(() {
          _pendingVoice = voice;
          _pendingVoicePath = path;
        });
      }
    } on Object catch (error) {
      _recordingTicker?.cancel();
      _recordingStartedAt = null;
      if (mounted) setState(() => _recording = false);
      _showSnack('Nie udało się wysłać głosówki: $error');
    }
  }

  Future<void> _playPendingVoice() async {
    final path = _pendingVoicePath;
    if (path == null) return;
    try {
      if (_voicePreviewPlayer?.playing ?? false) {
        await _voicePreviewPlayer?.stop();
        return;
      }
      final player = _voicePreviewPlayer ??= AudioPlayer();
      await player.setFilePath(path);
      await player.play();
    } on Object catch (error) {
      _showSnack('Nie udało się odtworzyć nagrania: $error');
    }
  }

  Future<void> _sendPendingVoice() async {
    final voice = _pendingVoice;
    if (voice == null) return;
    await _send(_controller.text, null, null, voice, null);
    if (mounted) {
      setState(() {
        _pendingVoice = null;
        _pendingVoicePath = null;
      });
    }
  }

  Future<void> _cancelPendingVoice() async {
    await _voicePreviewPlayer?.stop();
    _recordingTicker?.cancel();
    if (!mounted) return;
    setState(() {
      _pendingVoice = null;
      _pendingVoicePath = null;
    });
    _showSnack('Głosówka anulowana.');
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
    if (text.trim().isEmpty &&
        image == null &&
        video == null &&
        voice == null &&
        file == null) {
      return;
    }
    setState(() => _sending = true);
    _typingTimer?.cancel();
    _setTyping(false);
    try {
      final mentionIds = _selectedMentions.entries
          .where((entry) => text.contains('@${entry.value}'))
          .map((entry) => entry.key)
          .toSet()
          .toList();
      await widget.onSend(text, image, video, voice, file, mentionIds);
      _controller.clear();
      _selectedMentions.clear();
    } on Object {
      // The parent screen shows the detailed send error.
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
    if (!widget.enabled) return;
    if (_hasText) {
      _setTyping(true);
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 4), () {
        _setTyping(false);
      });
    } else {
      _typingTimer?.cancel();
      _setTyping(false);
    }
  }

  String? _mentionQuery() {
    final selection = _controller.selection;
    final offset = selection.isValid
        ? selection.baseOffset
        : _controller.text.length;
    final safeOffset = offset.clamp(0, _controller.text.length).toInt();
    final beforeCursor = _controller.text.substring(0, safeOffset);
    final marker = beforeCursor.lastIndexOf('@');
    if (marker < 0) return null;
    if (marker > 0 && beforeCursor[marker - 1].trim().isNotEmpty) return null;
    final query = beforeCursor.substring(marker + 1);
    if (query.contains(RegExp(r'\s'))) return null;
    return query.toLowerCase();
  }

  List<AppUser> _mentionSuggestions() {
    final query = _mentionQuery();
    if (query == null) return const [];
    return widget.mentionUsers
        .where((user) {
          final label = _mentionLabel(user).toLowerCase();
          return query.isEmpty ||
              label.contains(query) ||
              user.login.toLowerCase().contains(query);
        })
        .take(6)
        .toList();
  }

  void _insertMention(AppUser user) {
    final selection = _controller.selection;
    final offset = selection.isValid
        ? selection.baseOffset
        : _controller.text.length;
    final safeOffset = offset.clamp(0, _controller.text.length).toInt();
    final text = _controller.text;
    final beforeCursor = text.substring(0, safeOffset);
    final marker = beforeCursor.lastIndexOf('@');
    if (marker < 0) return;
    final label = _mentionLabel(user);
    final nextText =
        '${text.substring(0, marker)}@$label ${text.substring(safeOffset)}';
    final nextOffset = marker + label.length + 2;
    _selectedMentions[user.uid] = label;
    _controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextOffset),
    );
  }

  String _mentionLabel(AppUser user) {
    final nickname = user.nickname.trim();
    if (nickname.isNotEmpty) return nickname.replaceAll(RegExp(r'\s+'), '_');
    return user.login.replaceAll(RegExp(r'\s+'), '_');
  }

  void _setTyping(bool typing) {
    if (_typing == typing) return;
    _typing = typing;
    widget.onTypingChanged?.call(typing);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MentionSuggestions extends StatelessWidget {
  const _MentionSuggestions({required this.users, required this.onSelected});

  final List<AppUser> users;
  final ValueChanged<AppUser> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.panelAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final user in users)
            ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.panel,
                child: Text(_initials(user)),
              ),
              title: Text(user.nickname.isEmpty ? user.login : user.nickname),
              subtitle: Text(
                user.unitName.isEmpty ? user.unitType.label : user.unitName,
              ),
              onTap: () => onSelected(user),
            ),
        ],
      ),
    );
  }

  String _initials(AppUser user) {
    final text = user.nickname.isEmpty ? user.login : user.nickname;
    if (text.trim().isEmpty) return '@';
    return text.trim().characters.first.toUpperCase();
  }
}

class _RecordingBanner extends StatelessWidget {
  const _RecordingBanner({required this.elapsed, required this.onStop});

  final Duration elapsed;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.fiber_manual_record, color: AppColors.red, size: 16),
          const SizedBox(width: 8),
          Text(
            'REC $minutes:$seconds',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 12),
          const Expanded(child: LinearProgressIndicator(minHeight: 3)),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: onStop,
            icon: const Icon(Icons.stop),
            label: const Text('Zakończ'),
          ),
        ],
      ),
    );
  }
}

class _VoicePreviewActions extends StatelessWidget {
  const _VoicePreviewActions({
    required this.sending,
    required this.onPlay,
    required this.onSend,
    required this.onCancel,
  });

  final bool sending;
  final VoidCallback onPlay;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.panelAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Icon(Icons.graphic_eq, color: AppColors.orange),
          const Text('Głosówka gotowa'),
          OutlinedButton.icon(
            onPressed: sending ? null : onPlay,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Odtwórz'),
          ),
          FilledButton.icon(
            onPressed: sending ? null : onSend,
            icon: const Icon(Icons.send),
            label: const Text('Wyślij'),
          ),
          TextButton.icon(
            onPressed: sending ? null : onCancel,
            icon: const Icon(Icons.close),
            label: const Text('Anuluj'),
          ),
        ],
      ),
    );
  }
}

class _ToolButtons extends StatelessWidget {
  const _ToolButtons({
    required this.enabled,
    required this.recording,
    required this.onImage,
    required this.onCamera,
    required this.onVideo,
    required this.onFile,
    this.onVoice,
  });

  final bool enabled;
  final bool recording;
  final VoidCallback onImage;
  final VoidCallback onCamera;
  final VoidCallback onVideo;
  final VoidCallback? onVoice;
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
          tooltip: 'Aparat',
          icon: Icons.photo_camera_outlined,
          onPressed: enabled ? onCamera : null,
        ),
        _IconTool(
          tooltip: 'Wideo',
          icon: Icons.videocam_outlined,
          onPressed: enabled ? onVideo : null,
        ),
        if (onVoice != null || recording)
          _IconTool(
            tooltip: recording ? 'Zakończ i wyślij głosówkę' : 'Głosówka',
            icon: recording ? Icons.stop_circle_outlined : Icons.mic_none,
            color: recording ? AppColors.red : null,
            onPressed: enabled || recording ? onVoice : null,
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
    this.color,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 40,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: color),
      ),
    );
  }
}
