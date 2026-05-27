import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:tarnobrzeg112/models/private_chat.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/providers/chat_providers.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';
import 'package:tarnobrzeg112/providers/settings_providers.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
import 'package:tarnobrzeg112/services/chat_sound_service.dart';
import 'package:tarnobrzeg112/themes/app_colors.dart';
import 'package:tarnobrzeg112/utils/error_utils.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/empty_state.dart';
import 'package:tarnobrzeg112/widgets/loading_shimmer.dart';
import 'package:tarnobrzeg112/widgets/user_avatar.dart';

class ChatSettingsScreen extends ConsumerStatefulWidget {
  const ChatSettingsScreen({required this.chatId, super.key});

  final String chatId;

  @override
  ConsumerState<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends ConsumerState<ChatSettingsScreen> {
  static const _colors = <_Choice>[
    _Choice('#2563eb', 'Niebieski'),
    _Choice('#16a34a', 'Zielony'),
    _Choice('#dc2626', 'Czerwony'),
    _Choice('#7c3aed', 'Fioletowy'),
    _Choice('#0891b2', 'Turkusowy'),
    _Choice('#f8fafc', 'Jasny'),
    _Choice('#111827', 'Ciemny'),
  ];

  static const _presets = <_Choice>[
    _Choice('default', 'Domyślne'),
    _Choice('neon', 'Neon'),
    _Choice('cosmos', 'Kosmos'),
    _Choice('sunset', 'Zachód słońca'),
    _Choice('premium', 'Premium'),
    _Choice('waves', 'Fale'),
    _Choice('fire', '🚒 Straż'),
    _Choice('police', '🚓 Policja'),
    _Choice('rescue', '🚑 Ratownictwo'),
  ];

  static const _styles = <_Choice>[
    _Choice('rounded', 'Messenger'),
    _Choice('compact', 'Kompaktowy'),
    _Choice('soft', 'Miękki'),
  ];

  static const _modes = <_Choice>[
    _Choice('silent', 'Cichy'),
    _Choice('standard', 'Standard'),
    _Choice('loud', 'Głośny'),
  ];

  final _name = TextEditingController();
  final _memberSearch = TextEditingController();
  final _picker = ImagePicker();
  String? _hydratedChatId;
  String _themeColor = '#dc2626';
  String _messageStyle = 'rounded';
  String _chatTheme = 'default';
  String _backgroundType = 'preset';
  String _backgroundPreset = 'default';
  String _backgroundImageUrl = '';
  String _incomingSound = ChatSoundService.defaultIncomingSound;
  String _privateSound = ChatSoundService.defaultPrivateSound;
  String _newAccountSound = ChatSoundService.defaultIncomingSound;
  String _announcementSound = ChatSoundService.defaultIncomingSound;
  String _eventSound = ChatSoundService.defaultIncomingSound;
  String _mentionSound = ChatSoundService.defaultIncomingSound;
  String _notificationMode = 'loud';
  bool _vibrationEnabled = true;
  bool _saving = false;
  XFile? _pendingBackgroundImage;
  Uint8List? _pendingBackgroundPreview;

  @override
  void dispose() {
    _name.dispose();
    _memberSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentAppUserProvider).asData?.value;
    final chatState = ref.watch(privateChatProvider(widget.chatId));
    final personalizationKey = user == null
        ? null
        : ChatPersonalizationKey(uid: user.uid, chatId: widget.chatId);
    final personalizationState = personalizationKey == null
        ? null
        : ref.watch(chatPersonalizationProvider(personalizationKey));
    return AppScaffold(
      title: 'Ustawienia czatu',
      currentIndex: widget.chatId == 'main' || widget.chatId.startsWith('unit_')
          ? 1
          : 2,
      showBackButton: true,
      fallbackRoute: _fallbackRoute(),
      body: chatState.when(
        loading: () => const LoadingShimmer(
          timeoutTitle: 'Brak danych czatu',
          timeoutMessage: 'Nie można załadować ustawień.',
        ),
        error: (error, _) => EmptyState(
          icon: Icons.cloud_off,
          title: 'Nie można pobrać ustawień',
          message: ErrorUtils.readable(error),
          actionLabel: 'Odśwież',
          onAction: () => ref.invalidate(privateChatProvider(widget.chatId)),
        ),
        data: (chat) {
          if (user == null) {
            return const EmptyState(
              icon: Icons.lock_outline,
              title: 'Brak czatu',
              message: 'Nie znaleziono czatu albo sesji użytkownika.',
            );
          }
          if (chat == null && !_isShellChat(widget.chatId)) {
            return const EmptyState(
              icon: Icons.lock_outline,
              title: 'Brak czatu',
              message: 'Nie znaleziono czatu albo nie masz do niego dostępu.',
            );
          }
          final effectiveChat = chat ?? _shellChat(widget.chatId);
          final personalization = personalizationState?.asData?.value;
          _hydrate(effectiveChat, personalization);
          return _content(user, effectiveChat, personalization);
        },
      ),
    );
  }

  String _fallbackRoute() {
    if (widget.chatId == 'main') return RoutePaths.globalChat;
    if (widget.chatId.startsWith('unit_')) {
      return RoutePaths.unitChat(widget.chatId.replaceFirst('unit_', ''));
    }
    return RoutePaths.privateChat(widget.chatId);
  }

  bool _isShellChat(String chatId) {
    return chatId == 'main' || chatId.startsWith('unit_');
  }

  PrivateChat _shellChat(String chatId) {
    final isMain = chatId == 'main';
    return PrivateChat(
      id: chatId,
      participantIds: const [],
      participantNames: const {},
      updatedAt: DateTime.now(),
      createdAt: DateTime.now(),
      chatKind: isMain ? 'main' : 'unit',
      name: isMain
          ? 'Czat główny'
          : chatId.replaceFirst('unit_', '').replaceAll('_', ' '),
    );
  }

  Widget _content(
    AppUser user,
    PrivateChat chat,
    ChatPersonalizationSettings? personalization,
  ) {
    final users = ref.watch(activeUsersProvider).asData?.value ?? const [];
    final memberIds = chat.participantIds.toSet();
    final memberSearch = _memberSearch.text.trim();
    final searchResults = users
        .where(
          (candidate) =>
              candidate.uid != chat.ownerId &&
              _matchesMemberSearch(candidate, memberSearch),
        )
        .take(40)
        .toList();
    final members = users.where(
      (candidate) => memberIds.contains(candidate.uid),
    );
    final canManage =
        chat.isGroup &&
        (user.isAdmin ||
            user.uid == chat.ownerId ||
            user.moderatorCan('manageChatMembers'));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Section(
          icon: Icons.info_outline,
          title: 'Podstawowe',
          children: [
            TextField(
              controller: _name,
              enabled: true,
              decoration: const InputDecoration(
                labelText: 'Nazwa czatu',
                prefixIcon: Icon(Icons.edit_outlined),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Section(
          icon: Icons.notifications_active_outlined,
          title: 'Dźwięki',
          children: [
            _SoundPicker(
              label: 'Dźwięk przychodzącej wiadomości',
              value: _incomingSound,
              mode: _notificationMode,
              enabled: true,
              onChanged: (value) => setState(() => _incomingSound = value),
            ),
            _SoundPicker(
              label: 'Dźwięk prywatnej wiadomości',
              value: _privateSound,
              mode: _notificationMode,
              enabled: true,
              onChanged: (value) => setState(() => _privateSound = value),
            ),
            _SoundPicker(
              label: 'Dźwięk nowych kont oczekujących',
              value: _newAccountSound,
              mode: _notificationMode,
              enabled: true,
              onChanged: (value) => setState(() => _newAccountSound = value),
            ),
            _SoundPicker(
              label: 'Dźwięk komunikatów',
              value: _announcementSound,
              mode: _notificationMode,
              enabled: true,
              onChanged: (value) => setState(() => _announcementSound = value),
            ),
            _SoundPicker(
              label: 'Dźwięk wydarzeń',
              value: _eventSound,
              mode: _notificationMode,
              enabled: true,
              onChanged: (value) => setState(() => _eventSound = value),
            ),
            _SoundPicker(
              label: 'Dźwięk oznaczeń @',
              value: _mentionSound,
              mode: _notificationMode,
              enabled: true,
              onChanged: (value) => setState(() => _mentionSound = value),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickCustomSound,
                  icon: const Icon(Icons.add),
                  label: const Text('Dodaj własny dźwięk'),
                ),
                OutlinedButton.icon(
                  onPressed: _restoreDefaultSounds,
                  icon: const Icon(Icons.restore),
                  label: const Text('Przywróć standardowe'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _notificationMode,
              decoration: const InputDecoration(labelText: 'Tryb'),
              items: [
                for (final mode in _modes)
                  DropdownMenuItem(value: mode.id, child: Text(mode.label)),
              ],
              onChanged: (value) =>
                  setState(() => _notificationMode = value ?? 'loud'),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _vibrationEnabled,
              onChanged: (value) => setState(() => _vibrationEnabled = value),
              secondary: const Icon(Icons.vibration_outlined),
              title: const Text('Wibracje ON/OFF'),
              subtitle: const Text('Dotyczy sygnałów tego czatu.'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Section(
          icon: Icons.palette_outlined,
          title: '🎨 Wygląd',
          children: [
            Text('Kolor wiadomości', style: _labelStyle(context)),
            const SizedBox(height: 8),
            _ChoiceGrid(
              choices: _colors,
              selected: _themeColor,
              enabled: true,
              colorMode: true,
              onSelected: (value) => setState(() => _themeColor = value),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _messageStyle,
              decoration: const InputDecoration(labelText: 'Styl wiadomości'),
              items: [
                for (final style in _styles)
                  DropdownMenuItem(value: style.id, child: Text(style.label)),
              ],
              onChanged: (value) =>
                  setState(() => _messageStyle = value ?? 'rounded'),
            ),
            const SizedBox(height: 14),
            Text('Tło, gradienty i motywy', style: _labelStyle(context)),
            const SizedBox(height: 8),
            _ChoiceGrid(
              choices: _presets,
              selected: _backgroundPreset,
              enabled: true,
              onSelected: (value) {
                setState(() {
                  _backgroundPreset = value;
                  _chatTheme = value;
                  _backgroundType = 'preset';
                  _pendingBackgroundImage = null;
                  _pendingBackgroundPreview = null;
                });
              },
            ),
            const SizedBox(height: 12),
            _AppearancePreview(
              themeColor: _themeColor,
              messageStyle: _messageStyle,
              backgroundType: _backgroundType,
              backgroundPreset: _backgroundPreset,
              backgroundImageUrl: _backgroundImageUrl,
              pendingPreview: _pendingBackgroundPreview,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickBackground,
              icon: const Icon(Icons.image_outlined),
              label: const Text('Własne zdjęcie tła'),
            ),
            OutlinedButton.icon(
              onPressed: _stageResetAppearance,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Resetuj wygląd'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Section(
          icon: Icons.save_outlined,
          title: 'Zapis ustawień',
          children: [
            const Text(
              'Zmiany są tylko podglądem. Zostaną zapisane dopiero po użyciu przycisku Zapisz.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: !_saving
                        ? () => _save(chat, user, canManage: canManage)
                        : null,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Zapisz'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: !_saving
                        ? () => _cancelChanges(chat, personalization)
                        : null,
                    icon: const Icon(Icons.close),
                    label: const Text('Anuluj'),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text('Członkowie', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final member in members)
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(member.publicName),
              subtitle: Text(member.login),
              trailing: canManage && member.uid != chat.ownerId
                  ? IconButton(
                      tooltip: 'Usuń członka',
                      icon: const Icon(Icons.person_remove_outlined),
                      onPressed: () => _remove(chat, user, member.uid),
                    )
                  : null,
            ),
          ),
        if (canManage) ...[
          const SizedBox(height: 12),
          Text('Dodaj członka', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _memberSearch,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Szukaj użytkownika',
              hintText: 'Imię, nazwisko, pseudonim, login, jednostka, typ',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 8),
          if (searchResults.isEmpty)
            const EmptyState(
              icon: Icons.people_outline,
              title: 'Brak wyników',
              message:
                  'Wpisz fragment imienia, loginu, pseudonimu lub jednostki.',
            )
          else
            for (final candidate in searchResults)
              Card(
                child: ListTile(
                  leading: UserAvatar(user: candidate, radius: 22),
                  title: Text(_memberTitle(candidate)),
                  subtitle: Text(_memberSubtitle(candidate)),
                  trailing: memberIds.contains(candidate.uid)
                      ? const Text('Już dodany')
                      : FilledButton(
                          onPressed: () => _addMember(chat, user, candidate),
                          child: const Text('DODAJ'),
                        ),
                ),
              ),
        ],
      ],
    );
  }

  bool _matchesMemberSearch(AppUser user, String query) {
    if (query.isEmpty) return true;
    final haystack = [
      user.fullName,
      user.firstName,
      user.lastName,
      user.nickname,
      user.login,
      user.unitName,
      user.unitType.label,
      user.role.label,
    ].join(' ').toLowerCase();
    return haystack.contains(query.toLowerCase());
  }

  String _memberTitle(AppUser user) {
    final fullName = user.fullName.trim();
    return fullName.isEmpty ? user.publicName : fullName;
  }

  String _memberSubtitle(AppUser user) {
    final nickname = user.nickname.trim().isEmpty ? user.login : user.nickname;
    final service = user.unitName.trim().isEmpty
        ? user.unitType.label
        : user.unitName;
    return '$nickname • $service • ${user.unitType.label}';
  }

  TextStyle? _labelStyle(BuildContext context) {
    return Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900);
  }

  void _hydrate(
    PrivateChat chat,
    ChatPersonalizationSettings? personalization, {
    bool force = false,
  }) {
    final hydrationKey = [
      chat.id,
      personalization?.themeColor,
      personalization?.messageStyle,
      personalization?.chatTheme,
      personalization?.backgroundType,
      personalization?.backgroundImageUrl,
      personalization?.backgroundPreset,
      personalization?.incomingSound,
      personalization?.privateSound,
      personalization?.newAccountSound,
      personalization?.announcementSound,
      personalization?.eventSound,
      personalization?.mentionSound,
      personalization?.vibrationEnabled,
      personalization?.notificationMode,
    ].join('|');
    if (!force && _hydratedChatId == hydrationKey) return;
    _hydratedChatId = hydrationKey;
    _name.text = chat.name;
    _themeColor = _validChoice(
      _colors,
      _personalOrShared(personalization?.themeColor, chat.themeColor),
      '#dc2626',
    );
    _messageStyle = _validChoice(
      _styles,
      _personalOrShared(personalization?.messageStyle, chat.messageStyle),
      'rounded',
    );
    _chatTheme = _personalOrShared(
      personalization?.chatTheme,
      chat.chatTheme.isEmpty ? 'default' : chat.chatTheme,
    );
    _backgroundType = _personalOrShared(
      personalization?.backgroundType,
      chat.backgroundType,
    );
    _backgroundPreset = _validChoice(
      _presets,
      _personalOrShared(
        personalization?.backgroundPreset,
        chat.backgroundPreset,
      ),
      'default',
    );
    _backgroundImageUrl = _personalOrShared(
      personalization?.backgroundImageUrl,
      chat.backgroundImageUrl,
    );
    _incomingSound = _validSound(
      _personalOrShared(personalization?.incomingSound, chat.incomingSound),
      ChatSoundService.defaultIncomingSound,
    );
    _privateSound = _validSound(
      _personalOrShared(personalization?.privateSound, chat.privateSound),
      ChatSoundService.defaultPrivateSound,
    );
    _newAccountSound = _validSound(
      personalization?.newAccountSound ?? '',
      ChatSoundService.defaultIncomingSound,
    );
    _announcementSound = _validSound(
      personalization?.announcementSound ?? '',
      ChatSoundService.defaultIncomingSound,
    );
    _eventSound = _validSound(
      personalization?.eventSound ?? '',
      ChatSoundService.defaultIncomingSound,
    );
    _mentionSound = _validSound(
      personalization?.mentionSound ?? '',
      ChatSoundService.defaultIncomingSound,
    );
    _vibrationEnabled =
        personalization?.vibrationEnabled ?? chat.vibrationEnabled;
    _notificationMode = _validChoice(
      _modes,
      _personalOrShared(
        personalization?.notificationMode,
        chat.notificationMode,
      ),
      'loud',
    );
    _pendingBackgroundImage = null;
    _pendingBackgroundPreview = null;
  }

  String _validChoice(List<_Choice> choices, String value, String fallback) {
    return choices.any((choice) => choice.id == value) ? value : fallback;
  }

  String _validSound(String value, String fallback) {
    return ChatSoundService.isValid(value) ? value : fallback;
  }

  String _personalOrShared(String? personal, String shared) {
    final cleanPersonal = personal?.trim() ?? '';
    return cleanPersonal.isEmpty ? shared : cleanPersonal;
  }

  Future<void> _save(
    PrivateChat chat,
    AppUser user, {
    required bool canManage,
  }) async {
    setState(() => _saving = true);
    try {
      var imageUrl = _backgroundImageUrl;
      final pendingImage = _pendingBackgroundImage;
      if (pendingImage != null) {
        imageUrl = await ref
            .read(storageServiceProvider)
            .uploadChatBackground(chatId: chat.id, file: pendingImage);
      }
      await saveChatPersonalization(
        key: ChatPersonalizationKey(uid: user.uid, chatId: chat.id),
        settings: ChatPersonalizationSettings(
          themeColor: _themeColor,
          messageStyle: _messageStyle,
          chatTheme: _chatTheme,
          backgroundType: _backgroundType,
          backgroundPreset: _backgroundPreset,
          backgroundImageUrl: imageUrl,
          incomingSound: _incomingSound,
          privateSound: _privateSound,
          newAccountSound: _newAccountSound,
          announcementSound: _announcementSound,
          eventSound: _eventSound,
          mentionSound: _mentionSound,
          vibrationEnabled: _vibrationEnabled,
          notificationMode: _notificationMode,
        ),
      );
      if (canManage && _name.text.trim() != chat.name.trim()) {
        await ref
            .read(privateChatRepositoryProvider)
            .updateChatName(chat: chat, actor: user, name: _name.text);
      }
      _backgroundImageUrl = imageUrl;
      _pendingBackgroundImage = null;
      _pendingBackgroundPreview = null;
      ref.read(chatPersonalizationRevisionProvider.notifier).state++;
      ref.invalidate(privateChatProvider(widget.chatId));
      _show('Ustawienia zapisane.');
    } on Object catch (error) {
      _show('Nie udało się zapisać ustawień: ${ErrorUtils.readable(error)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickBackground() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1800,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pendingBackgroundImage = image;
      _pendingBackgroundPreview = bytes;
      _backgroundType = 'image';
    });
    _show('Zdjęcie tła wybrane. Użyj Zapisz, aby je zastosować.');
  }

  void _stageResetAppearance() {
    setState(() {
      _themeColor = '#dc2626';
      _messageStyle = 'rounded';
      _chatTheme = 'default';
      _backgroundType = 'preset';
      _backgroundPreset = 'default';
      _backgroundImageUrl = '';
      _pendingBackgroundImage = null;
      _pendingBackgroundPreview = null;
    });
  }

  void _cancelChanges(
    PrivateChat chat,
    ChatPersonalizationSettings? personalization,
  ) {
    setState(() => _hydrate(chat, personalization, force: true));
    _show('Zmiany anulowane.');
  }

  Future<void> _pickCustomSound() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'ogg', 'm4a'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return;
    final id = file.bytes != null
        ? ChatSoundService.customDataId(
            name: file.name,
            mimeType: _audioMime(file.extension),
            bytes: file.bytes!,
          )
        : file.path == null
        ? null
        : ChatSoundService.customFileId(name: file.name, path: file.path!);
    if (id == null) {
      _show('Nie udało się odczytać wybranego dźwięku.');
      return;
    }
    if (!mounted) return;
    final target = await showModalBottomSheet<_SoundTarget>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            for (final target in _SoundTarget.values)
              ListTile(
                leading: const Icon(Icons.music_note_outlined),
                title: Text(target.label),
                onTap: () => Navigator.pop(context, target),
              ),
          ],
        ),
      ),
    );
    if (target == null) return;
    setState(() => _assignSound(target, id));
    _show('Własny dźwięk dodany. Użyj Zapisz, aby go zachować.');
  }

  void _restoreDefaultSounds() {
    setState(() {
      _incomingSound = ChatSoundService.defaultIncomingSound;
      _privateSound = ChatSoundService.defaultPrivateSound;
      _newAccountSound = ChatSoundService.defaultIncomingSound;
      _announcementSound = ChatSoundService.defaultIncomingSound;
      _eventSound = ChatSoundService.defaultIncomingSound;
      _mentionSound = ChatSoundService.defaultIncomingSound;
    });
    _show('Przywrócono standardowe dźwięki w podglądzie.');
  }

  void _assignSound(_SoundTarget target, String id) {
    switch (target) {
      case _SoundTarget.incoming:
        _incomingSound = id;
      case _SoundTarget.private:
        _privateSound = id;
      case _SoundTarget.newAccounts:
        _newAccountSound = id;
      case _SoundTarget.announcements:
        _announcementSound = id;
      case _SoundTarget.events:
        _eventSound = id;
      case _SoundTarget.mentions:
        _mentionSound = id;
    }
  }

  String _audioMime(String? extension) {
    return switch ((extension ?? '').toLowerCase()) {
      'wav' => 'audio/wav',
      'ogg' => 'audio/ogg',
      'm4a' => 'audio/mp4',
      _ => 'audio/mpeg',
    };
  }

  Future<void> _addMember(
    PrivateChat chat,
    AppUser actor,
    AppUser member,
  ) async {
    try {
      await ref
          .read(privateChatRepositoryProvider)
          .addParticipant(chat: chat, actor: actor, user: member);
      _show('Dodano użytkownika');
      if (mounted) {
        setState(() {
          _memberSearch.clear();
        });
      }
    } on Object catch (error) {
      _show('Nie udało się dodać członka: ${ErrorUtils.readable(error)}');
    }
  }

  Future<void> _remove(PrivateChat chat, AppUser actor, String uid) async {
    try {
      await ref
          .read(privateChatRepositoryProvider)
          .removeParticipant(chat: chat, actor: actor, uid: uid);
      _show('Członek usunięty.');
    } on Object catch (error) {
      _show('Nie udało się usunąć członka: ${ErrorUtils.readable(error)}');
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SoundPicker extends StatelessWidget {
  const _SoundPicker({
    required this.label,
    required this.value,
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String value;
  final String mode;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final customSelected = ChatSoundService.isCustom(value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: value,
              decoration: InputDecoration(labelText: label),
              items: [
                if (customSelected)
                  DropdownMenuItem(
                    value: value,
                    child: Text(ChatSoundService.customLabel(value)),
                  ),
                for (final option in ChatSoundService.options)
                  DropdownMenuItem(value: option.id, child: Text(option.label)),
              ],
              onChanged: enabled
                  ? (next) =>
                        onChanged(next ?? ChatSoundService.options.last.id)
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox.square(
            dimension: 52,
            child: IconButton.filledTonal(
              tooltip: 'Odsłuch',
              onPressed: enabled
                  ? () => ChatSoundService.preview(value, mode: mode)
                  : null,
              icon: const Icon(Icons.play_arrow),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceGrid extends StatelessWidget {
  const _ChoiceGrid({
    required this.choices,
    required this.selected,
    required this.enabled,
    required this.onSelected,
    this.colorMode = false,
  });

  final List<_Choice> choices;
  final String selected;
  final bool enabled;
  final bool colorMode;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final choice in choices)
          ChoiceChip(
            selected: selected == choice.id,
            onSelected: enabled ? (_) => onSelected(choice.id) : null,
            avatar: colorMode
                ? CircleAvatar(backgroundColor: _colorFromHex(choice.id))
                : null,
            label: Text(choice.label),
          ),
      ],
    );
  }
}

class _AppearancePreview extends StatelessWidget {
  const _AppearancePreview({
    required this.themeColor,
    required this.messageStyle,
    required this.backgroundType,
    required this.backgroundPreset,
    required this.backgroundImageUrl,
    required this.pendingPreview,
  });

  final String themeColor;
  final String messageStyle;
  final String backgroundType;
  final String backgroundPreset;
  final String backgroundImageUrl;
  final Uint8List? pendingPreview;

  @override
  Widget build(BuildContext context) {
    final accent = _colorFromHex(themeColor) ?? const Color(0xFFDC2626);
    final subtitle = backgroundType == 'image'
        ? 'Własne zdjęcie tła'
        : 'Motyw: ${_presetLabel(backgroundPreset)}';
    return Container(
      height: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: _gradientFor(backgroundPreset),
        image: pendingPreview != null
            ? DecorationImage(
                image: MemoryImage(pendingPreview!),
                fit: BoxFit.cover,
                opacity: 0.34,
              )
            : backgroundType == 'image' && backgroundImageUrl.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(backgroundImageUrl),
                fit: BoxFit.cover,
                opacity: 0.34,
                onError: (_, _) {},
              )
            : null,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Podgląd',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 260),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(_radiusFor(messageStyle)),
              ),
              child: const Text(
                'Przykładowa wiadomość',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(subtitle, style: const TextStyle(color: AppColors.white)),
        ],
      ),
    );
  }

  double _radiusFor(String style) {
    return switch (style) {
      'compact' => 10,
      'soft' => 24,
      _ => 18,
    };
  }

  String _presetLabel(String preset) {
    return _ChatSettingsScreenState._presets
        .firstWhere(
          (choice) => choice.id == preset,
          orElse: () => const _Choice('default', 'Domyślne'),
        )
        .label;
  }

  LinearGradient _gradientFor(String preset) {
    final colors = switch (preset) {
      'neon' => [const Color(0xFF111827), const Color(0xFF06B6D4)],
      'cosmos' => [const Color(0xFF020617), const Color(0xFF7C3AED)],
      'sunset' => [const Color(0xFF7F1D1D), const Color(0xFFF97316)],
      'premium' => [const Color(0xFF111827), const Color(0xFFD97706)],
      'waves' => [const Color(0xFF082F49), const Color(0xFF14B8A6)],
      'fire' => [const Color(0xFF1F0808), const Color(0xFFDC2626)],
      'police' => [const Color(0xFF020617), const Color(0xFF2563EB)],
      'rescue' => [const Color(0xFF052E16), const Color(0xFF16A34A)],
      _ => [Colors.black26, Colors.black12],
    };
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    );
  }
}

class _Choice {
  const _Choice(this.id, this.label);

  final String id;
  final String label;
}

enum _SoundTarget {
  incoming('Dźwięk wiadomości czatu głównego'),
  private('Dźwięk wiadomości prywatnych'),
  newAccounts('Dźwięk nowych kont oczekujących'),
  announcements('Dźwięk komunikatów'),
  events('Dźwięk wydarzeń'),
  mentions('Dźwięk oznaczeń @');

  const _SoundTarget(this.label);

  final String label;
}

Color? _colorFromHex(String value) {
  final clean = value.replaceFirst('#', '').trim();
  if (clean.length != 6) return null;
  final parsed = int.tryParse('ff$clean', radix: 16);
  return parsed == null ? null : Color(parsed);
}
