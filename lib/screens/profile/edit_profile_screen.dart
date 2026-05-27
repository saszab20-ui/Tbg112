import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
import 'package:tarnobrzeg112/utils/error_utils.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/empty_state.dart';
import 'package:tarnobrzeg112/widgets/glass_panel.dart';
import 'package:tarnobrzeg112/widgets/loading_shimmer.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _fullName = TextEditingController();
  final _nickname = TextEditingController();
  final _phoneNumber = TextEditingController();
  final _description = TextEditingController();
  final _customStatus = TextEditingController();
  final _picker = ImagePicker();
  XFile? _avatar;
  String? _initializedUid;
  bool _saving = false;

  @override
  void dispose() {
    _fullName.dispose();
    _nickname.dispose();
    _phoneNumber.dispose();
    _description.dispose();
    _customStatus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentAppUserProvider);
    return AppScaffold(
      title: 'Edytuj profil',
      currentIndex: 4,
      showBackButton: true,
      fallbackRoute: RoutePaths.profile,
      body: userAsync.when(
        loading: () => LoadingShimmer(
          timeoutTitle: 'Brak danych profilu',
          timeoutMessage: 'Nie można przygotować formularza edycji.',
          onRefresh: () => ref.invalidate(currentAppUserProvider),
        ),
        error: (error, _) => EmptyState(
          icon: Icons.cloud_off,
          title: 'Nie można pobrać profilu',
          message: ErrorUtils.readable(error),
          actionLabel: 'Odśwież',
          onAction: () => ref.invalidate(currentAppUserProvider),
        ),
        data: (user) {
          if (user == null) {
            return const EmptyState(
              icon: Icons.person_off_outlined,
              title: 'Brak danych profilu',
              message: 'Nie znaleziono profilu dla aktywnej sesji.',
            );
          }
          _initialize(user);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassPanel(
                child: Column(
                  children: [
                    if (!user.hasFullName) ...[
                      TextFormField(
                        controller: _fullName,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Imię i nazwisko',
                          helperText: 'Wymagane uzupełnienie danych konta',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _nickname,
                      decoration: const InputDecoration(
                        labelText: 'Pseudonim',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneNumber,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Telefon',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _description,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Opis',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PresenceStatusPicker(
                      currentStatus: user.presenceStatus,
                      customStatusController: _customStatus,
                      onChanged: (status) {
                        if (status != PresenceStatus.manual) {
                          ref
                              .read(usersRepositoryProvider)
                              .updatePresence(user.uid, status, manual: true);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _pickAvatar,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(
                        _avatar == null ? 'Zmień avatar' : 'Avatar wybrany',
                      ),
                    ),
                    if (_avatar != null) ...[
                      const SizedBox(height: 10),
                      _AvatarPreview(file: _avatar!),
                    ],
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _saving ? null : () => _save(user),
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('Zapisz'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _initialize(AppUser user) {
    if (_initializedUid == user.uid) return;
    _initializedUid = user.uid;
    _fullName.text = user.fullName;
    _nickname.text = user.nickname;
    _phoneNumber.text = user.phoneNumber;
    _description.text = user.description;
    _customStatus.text = user.customStatus;
  }

  Future<void> _pickAvatar() async {
    final avatar = await _picker.pickImage(source: ImageSource.gallery);
    if (avatar != null) setState(() => _avatar = avatar);
  }

  Future<void> _save(AppUser user) async {
    setState(() => _saving = true);
    try {
      final nameParts = _splitFullName(_fullName.text);
      if (!user.hasFullName && nameParts == null) {
        throw StateError('Wpisz imię i nazwisko.');
      }
      if (_customStatus.text.trim().isNotEmpty) {
        await ref
            .read(usersRepositoryProvider)
            .setCustomStatus(user.uid, _customStatus.text);
      }
      await ref
          .read(usersRepositoryProvider)
          .updateEditableProfile(
            user: user,
            nickname: _nickname.text,
            phoneNumber: _phoneNumber.text,
            description: _description.text,
            firstName: nameParts?.first,
            lastName: nameParts?.last,
            avatar: _avatar,
          );
      if (mounted) context.go(RoutePaths.profile);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nie udało się zapisać: ${ErrorUtils.readable(error)}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String>? _splitFullName(String value) {
    final parts = value
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length < 2) return null;
    return [parts.first, parts.skip(1).join(' ')];
  }
}

class _PresenceStatusPicker extends StatelessWidget {
  const _PresenceStatusPicker({
    required this.currentStatus,
    required this.customStatusController,
    required this.onChanged,
  });

  final PresenceStatus currentStatus;
  final TextEditingController customStatusController;
  final ValueChanged<PresenceStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status aktywności',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<PresenceStatus>(
          initialValue: currentStatus,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.circle_notifications_outlined),
          ),
          items: [
            for (final status in PresenceStatus.values)
              if (status != PresenceStatus.unavailable)
                DropdownMenuItem(
                  value: status,
                  child: Text(status.label),
                ),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
        if (currentStatus == PresenceStatus.manual) ...[
          const SizedBox(height: 12),
          TextField(
            controller: customStatusController,
            decoration: const InputDecoration(
              labelText: 'Twój status',
              hintText: 'np. Na akcji, W drodze...',
              prefixIcon: Icon(Icons.edit_note),
            ),
          ),
        ],
      ],
    );
  }
}

class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({required this.file});

  final XFile file;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        return Align(
          alignment: Alignment.centerLeft,
          child: CircleAvatar(
            radius: 34,
            backgroundImage: bytes == null ? null : MemoryImage(bytes),
            child: bytes == null
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
        );
      },
    );
  }
}
