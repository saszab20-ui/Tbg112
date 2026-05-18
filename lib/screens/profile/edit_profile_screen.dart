import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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
  final _nickname = TextEditingController();
  final _phoneNumber = TextEditingController();
  final _description = TextEditingController();
  final _picker = ImagePicker();
  XFile? _avatar;
  String? _initializedUid;
  bool _saving = false;

  @override
  void dispose() {
    _nickname.dispose();
    _phoneNumber.dispose();
    _description.dispose();
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
                    OutlinedButton.icon(
                      onPressed: _pickAvatar,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(
                        _avatar == null ? 'Zmień avatar' : 'Avatar wybrany',
                      ),
                    ),
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
    _nickname.text = user.nickname;
    _phoneNumber.text = user.phoneNumber;
    _description.text = user.description;
  }

  Future<void> _pickAvatar() async {
    final avatar = await _picker.pickImage(source: ImageSource.gallery);
    if (avatar != null) setState(() => _avatar = avatar);
  }

  Future<void> _save(AppUser user) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(usersRepositoryProvider)
          .updateEditableProfile(
            user: user,
            nickname: _nickname.text,
            phoneNumber: _phoneNumber.text,
            description: _description.text,
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
}
