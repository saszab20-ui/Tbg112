import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tarnobrzeg112/core/app_constants.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/core/locations.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';
import 'package:tarnobrzeg112/repositories/auth_repository.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
import 'package:tarnobrzeg112/widgets/app_background.dart';
import 'package:tarnobrzeg112/widgets/glass_panel.dart';
import 'package:tarnobrzeg112/widgets/tbg_logo.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _login = TextEditingController();
  final _nickname = TextEditingController();
  final _password = TextEditingController();
  final _unitName = TextEditingController();
  final _picker = ImagePicker();

  UnitType _unitType = UnitType.osp;
  String _voivodeship = AppConstants.defaultVoivodeship;
  String _county = AppConstants.defaultCounty;
  XFile? _avatar;
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _fullName.dispose();
    _login.dispose();
    _nickname.dispose();
    _password.dispose();
    _unitName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final counties = AppLocations.countiesFor(_voivodeship);
    if (!counties.contains(_county)) {
      _county = counties.first;
    }

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Rejestracja')),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, viewport) {
              final compactScreen = viewport.maxWidth < 600;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      compactScreen ? 14 : 20,
                      12,
                      compactScreen ? 14 : 20,
                      20,
                    ),
                    children: [
                      const TbgLogo(size: 58),
                      const SizedBox(height: 14),
                      GlassPanel(
                        child: Form(
                          key: _formKey,
                          child: LayoutBuilder(
                            builder: (context, formConstraints) {
                              final compact = formConstraints.maxWidth < 560;
                              return Column(
                                children: [
                                  _responsivePair(
                                    compact: compact,
                                    first: _fullNameField(
                                      _fullName,
                                      'Imię i nazwisko',
                                      prefixIcon: Icons.badge_outlined,
                                    ),
                                    second: _field(
                                      _login,
                                      'Login',
                                      minLength: 3,
                                      prefixIcon: Icons.account_circle_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _responsivePair(
                                    compact: compact,
                                    first: _field(
                                      _nickname,
                                      'Pseudonim opcjonalnie',
                                      required: false,
                                      minLength: 2,
                                      prefixIcon: Icons.person_outline,
                                    ),
                                    second: _field(
                                      _password,
                                      'Hasło',
                                      obscureText: _obscurePassword,
                                      minLength: 6,
                                      prefixIcon: Icons.lock_outline,
                                      suffixIcon: IconButton(
                                        tooltip: _obscurePassword
                                            ? 'Pokaż hasło'
                                            : 'Ukryj hasło',
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                        onPressed: () => setState(
                                          () => _obscurePassword =
                                              !_obscurePassword,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _responsivePair(
                                    compact: compact,
                                    first: DropdownButtonFormField<String>(
                                      initialValue: _voivodeship,
                                      decoration: const InputDecoration(
                                        labelText: 'Województwo',
                                        prefixIcon: Icon(Icons.map_outlined),
                                      ),
                                      items: AppLocations.voivodeships
                                          .map(
                                            (value) => DropdownMenuItem(
                                              value: value,
                                              child: Text(value),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setState(() {
                                          _voivodeship = value;
                                          _county = AppLocations.countiesFor(
                                            value,
                                          ).first;
                                        });
                                      },
                                    ),
                                    second: DropdownButtonFormField<String>(
                                      initialValue: _county,
                                      decoration: const InputDecoration(
                                        labelText: 'Powiat',
                                        prefixIcon: Icon(Icons.location_city),
                                      ),
                                      items: counties
                                          .map(
                                            (value) => DropdownMenuItem(
                                              value: value,
                                              child: Text(value),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() => _county = value);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<UnitType>(
                                    initialValue: _unitType,
                                    decoration: const InputDecoration(
                                      labelText: 'Typ użytkownika',
                                      prefixIcon: Icon(Icons.shield_outlined),
                                    ),
                                    items:
                                        const [
                                              UnitType.osp,
                                              UnitType.psp,
                                              UnitType.policja,
                                              UnitType.zrm,
                                              UnitType.media,
                                              UnitType.informator,
                                              UnitType.inne,
                                            ]
                                            .map(
                                              (type) => DropdownMenuItem(
                                                value: type,
                                                child: Text(type.label),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() => _unitType = value);
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _field(
                                    _unitName,
                                    _unitType.hasOwnUnitChat
                                        ? 'Nazwa jednostki'
                                        : 'Funkcja / opis opcjonalnie',
                                    required: _unitType.hasOwnUnitChat,
                                    prefixIcon: Icons.apartment_outlined,
                                  ),
                                  const SizedBox(height: 14),
                                  OutlinedButton.icon(
                                    onPressed: _pickAvatar,
                                    icon: const Icon(
                                      Icons.account_circle_outlined,
                                    ),
                                    label: Text(
                                      _avatar == null
                                          ? 'Dodaj avatar'
                                          : 'Avatar wybrany',
                                    ),
                                  ),
                                  if (_avatar != null) ...[
                                    const SizedBox(height: 10),
                                    _AvatarPreview(file: _avatar!),
                                  ],
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: _loading ? null : _submit,
                                      icon: _loading
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.person_add_alt),
                                      label: const Text('Wyślij do akceptacji'),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        context.go(RoutePaths.login),
                                    child: const Text('Mam już konto'),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _responsivePair({
    required bool compact,
    required Widget first,
    required Widget second,
  }) {
    if (compact) {
      return Column(children: [first, const SizedBox(height: 12), second]);
    }
    return Row(
      children: [
        Expanded(child: first),
        const SizedBox(width: 12),
        Expanded(child: second),
      ],
    );
  }

  TextFormField _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    bool obscureText = false,
    int minLength = 1,
    bool required = true,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
      ),
      onChanged: (_) => setState(() {}),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (!required && text.isEmpty) return null;
        if (text.length < minLength) return 'Minimum $minLength znaków';
        return null;
      },
    );
  }

  TextFormField _fullNameField(
    TextEditingController controller,
    String label, {
    IconData? prefixIcon,
  }) {
    return TextFormField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
      ),
      onChanged: (_) => setState(() {}),
      validator: (value) {
        final text = value?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
        final parts = text.split(' ').where((part) => part.isNotEmpty).toList();
        if (text.length < 5 || parts.length < 2) {
          return 'Wpisz imię i nazwisko.';
        }
        return null;
      },
    );
  }

  Future<void> _pickAvatar() async {
    final avatar = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1200,
    );
    if (avatar != null) setState(() => _avatar = avatar);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final login = _login.text.trim();
    final nameParts = _splitFullName(_fullName.text);
    try {
      await ref
          .read(authRepositoryProvider)
          .register(
            RegisterData(
              firstName: nameParts.first,
              lastName: nameParts.last,
              nickname: _nickname.text,
              login: login,
              password: _password.text,
              phoneNumber: '',
              unitType: _unitType,
              unitName: _unitName.text,
              voivodeship: _voivodeship,
              county: _county,
              inviteCode: '',
              adminNotes: '',
              avatar: _avatar,
            ),
          );
      if (!mounted) return;
      ref.invalidate(authStateProvider);
      ref.invalidate(currentAppUserProvider);
      context.go(RoutePaths.loading);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _errorMessage(Object error) {
    final message = error.toString().replaceFirst('Bad state: ', '');
    if (message.contains('email-already-in-use')) {
      return 'Rejestracja nie powiodła się: ten login jest już zajęty.';
    }
    if (message.contains('wrong-password') ||
        message.contains('invalid-credential')) {
      return 'Rejestracja nie powiodła się: konto już istnieje, ale podane hasło jest nieprawidłowe.';
    }
    return 'Rejestracja nie powiodła się: $message';
  }

  List<String> _splitFullName(String value) {
    final parts = value
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length < 2) return [value.trim(), ''];
    return [parts.first, parts.skip(1).join(' ')];
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
