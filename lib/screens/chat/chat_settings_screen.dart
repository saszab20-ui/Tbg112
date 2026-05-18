import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
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

class ChatSettingsScreen extends ConsumerStatefulWidget {
  const ChatSettingsScreen({required this.chatId, super.key});

  final String chatId;

  @override
  ConsumerState<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends ConsumerState<ChatSettingsScreen> {
  final _name = TextEditingController();
  final _picker = ImagePicker();
  String _themeColor = '#ff3b30';
  String _backgroundType = 'preset';
  String _backgroundPreset = 'default';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentAppUserProvider).asData?.value;
    final chatState = ref.watch(privateChatProvider(widget.chatId));
    return AppScaffold(
      title: 'Ustawienia czatu',
      currentIndex: 2,
      showBackButton: true,
      fallbackRoute: RoutePaths.privateChat(widget.chatId),
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
          if (chat == null || user == null) {
            return const EmptyState(
              icon: Icons.lock_outline,
              title: 'Brak czatu',
              message: 'Nie znaleziono czatu albo sesji użytkownika.',
            );
          }
          _hydrate(chat);
          return _content(user, chat);
        },
      ),
    );
  }

  Widget _content(AppUser user, PrivateChat chat) {
    final users = ref.watch(activeUsersProvider).asData?.value ?? const [];
    final memberIds = chat.participantIds.toSet();
    final candidates = users
        .where((candidate) => !memberIds.contains(candidate.uid))
        .toList();
    final members = users.where(
      (candidate) => memberIds.contains(candidate.uid),
    );
    final canManage = user.isAdmin || user.uid == chat.ownerId;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _name,
          enabled: canManage,
          decoration: const InputDecoration(
            labelText: 'Nazwa czatu',
            prefixIcon: Icon(Icons.edit_outlined),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _themeColor,
          decoration: const InputDecoration(labelText: 'Kolor czatu'),
          items: const [
            DropdownMenuItem(
              value: '#ff3b30',
              child: Text('Alarmowy czerwony'),
            ),
            DropdownMenuItem(value: '#ff9f1c', child: Text('Pomarańczowy')),
            DropdownMenuItem(value: '#00d4ff', child: Text('Neon cyan')),
            DropdownMenuItem(value: '#22c55e', child: Text('Zielony')),
          ],
          onChanged: canManage
              ? (value) => setState(() => _themeColor = value ?? _themeColor)
              : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _backgroundPreset,
          decoration: const InputDecoration(labelText: 'Tło z motywu'),
          items: const [
            DropdownMenuItem(value: 'default', child: Text('Domyślne')),
            DropdownMenuItem(value: 'dark-grid', child: Text('Ciemna siatka')),
            DropdownMenuItem(value: 'red-alert', child: Text('Alarm')),
            DropdownMenuItem(value: 'blue-service', child: Text('Służby')),
          ],
          onChanged: canManage
              ? (value) {
                  setState(() {
                    _backgroundPreset = value ?? _backgroundPreset;
                    _backgroundType = 'preset';
                  });
                }
              : null,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: canManage ? () => _pickBackground(chat, user) : null,
          icon: const Icon(Icons.image_outlined),
          label: const Text('Ustaw tło ze zdjęcia'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: canManage && !_saving ? () => _save(chat, user) : null,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Zapisz ustawienia'),
        ),
        const SizedBox(height: 18),
        _InviteCard(chat: chat, user: user, canManage: canManage),
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
        const SizedBox(height: 12),
        Text('Dodaj członka', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (candidates.isEmpty)
          const EmptyState(
            icon: Icons.people_outline,
            title: 'Brak użytkowników do dodania',
            message: 'Wszyscy załadowani aktywni użytkownicy są już w czacie.',
          )
        else
          for (final candidate in candidates)
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_add_alt)),
                title: Text(candidate.publicName),
                subtitle: Text(candidate.login),
                onTap: canManage
                    ? () => _addMembers(chat, user, [...members, candidate])
                    : null,
              ),
            ),
      ],
    );
  }

  void _hydrate(PrivateChat chat) {
    if (_name.text.isEmpty) _name.text = chat.name;
    _themeColor = chat.themeColor.isEmpty ? _themeColor : chat.themeColor;
    _backgroundType = chat.backgroundType;
    _backgroundPreset = chat.backgroundPreset;
  }

  Future<void> _save(PrivateChat chat, AppUser user) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(privateChatRepositoryProvider)
          .updateChatSettings(
            chat: chat,
            actor: user,
            name: _name.text,
            themeColor: _themeColor,
            backgroundType: _backgroundType,
            backgroundPreset: _backgroundPreset,
          );
      _show('Ustawienia zapisane.');
    } on Object catch (error) {
      _show('Nie udało się zapisać ustawień: ${ErrorUtils.readable(error)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickBackground(PrivateChat chat, AppUser user) async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1800,
    );
    if (image == null) return;
    setState(() => _saving = true);
    try {
      final url = await ref
          .read(storageServiceProvider)
          .uploadChatBackground(chatId: chat.id, file: image);
      await ref
          .read(privateChatRepositoryProvider)
          .updateChatSettings(
            chat: chat,
            actor: user,
            name: _name.text,
            themeColor: _themeColor,
            backgroundType: 'image',
            backgroundPreset: _backgroundPreset,
            backgroundImageUrl: url,
          );
      _show('Tło czatu zapisane.');
    } on Object catch (error) {
      _show('Nie udało się ustawić tła: ${ErrorUtils.readable(error)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addMembers(
    PrivateChat chat,
    AppUser actor,
    Iterable<AppUser> members,
  ) async {
    try {
      await ref
          .read(privateChatRepositoryProvider)
          .updateGroupParticipants(
            chat: chat,
            actor: actor,
            participants: members.toList(),
          );
      _show('Członek dodany.');
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

class _InviteCard extends ConsumerWidget {
  const _InviteCard({
    required this.chat,
    required this.user,
    required this.canManage,
  });

  final PrivateChat chat;
  final AppUser user;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Link zaproszenia',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (chat.inviteLink?.isNotEmpty == true)
              SelectableText(chat.inviteLink!)
            else
              const Text('Brak aktywnego linku.'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: canManage
                      ? () async {
                          try {
                            final result = await ref
                                .read(privateChatRepositoryProvider)
                                .createInviteLink(chat: chat, actor: user);
                            if (context.mounted) {
                              await Clipboard.setData(
                                ClipboardData(text: result.inviteLink),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Link utworzony i skopiowany.'),
                                ),
                              );
                            }
                          } on Object catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ErrorUtils.readable(error)),
                                ),
                              );
                            }
                          }
                        }
                      : null,
                  icon: const Icon(Icons.link),
                  label: const Text('Wygeneruj link'),
                ),
                OutlinedButton.icon(
                  onPressed: chat.inviteLink?.isNotEmpty == true
                      ? () => Clipboard.setData(
                          ClipboardData(text: chat.inviteLink!),
                        )
                      : null,
                  icon: const Icon(Icons.copy),
                  label: const Text('Kopiuj'),
                ),
                OutlinedButton.icon(
                  onPressed: canManage && chat.inviteCode?.isNotEmpty == true
                      ? () => ref
                            .read(privateChatRepositoryProvider)
                            .deactivateInvite(chat: chat, actor: user)
                      : null,
                  icon: const Icon(Icons.link_off),
                  label: const Text('Dezaktywuj'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
