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
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _nickname = TextEditingController();
  final _login = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _unitName = TextEditingController();
  final _inviteCode = TextEditingController();
  final _adminNotes = TextEditingController();
  final _picker = ImagePicker();

  UnitType _unitType = UnitType.osp;
  String _voivodeship = AppConstants.defaultVoivodeship;
  String _county = AppConstants.defaultCounty;
  XFile? _avatar;
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _nickname.dispose();
    _login.dispose();
    _phone.dispose();
    _password.dispose();
    _unitName.dispose();
    _inviteCode.dispose();
    _adminNotes.dispose();
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const TbgLogo(size: 58),
                  const SizedBox(height: 18),
                  GlassPanel(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _field(
                                  _firstName,
                                  'Imię opcjonalnie',
                                  required: false,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _field(
                                  _lastName,
                                  'Nazwisko opcjonalnie',
                                  required: false,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _field(_nickname, 'Pseudonim')),
                              const SizedBox(width: 12),
                              Expanded(child: _field(_login, 'Login')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _field(
                                  _phone,
                                  'Telefon opcjonalnie',
                                  keyboardType: TextInputType.phone,
                                  required: false,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _field(
                                  _password,
                                  'Hasło',
                                  obscureText: _obscurePassword,
                                  minLength: 6,
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
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
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
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
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
                            ],
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
                          ),
                          const SizedBox(height: 12),
                          _field(
                            _adminNotes,
                            'Uwagi do administratora opcjonalnie',
                            required: false,
                          ),
                          const SizedBox(height: 12),
                          _field(
                            _inviteCode,
                            'Kod zaproszenia',
                            required: !AuthRepository.skipsInviteCode(
                              _login.text,
                            ),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: _pickAvatar,
                            icon: const Icon(Icons.account_circle_outlined),
                            label: Text(
                              _avatar == null
                                  ? 'Dodaj avatar'
                                  : 'Avatar wybrany',
                            ),
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
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
                          TextButton(
                            onPressed: () => context.go(RoutePaths.login),
                            child: const Text('Mam już konto'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  TextFormField _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    bool obscureText = false,
    int minLength = 1,
    bool required = true,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(labelText: label, suffixIcon: suffixIcon),
      onChanged: (_) => setState(() {}),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (!required && text.isEmpty) return null;
        if (text.length < minLength) return 'Minimum $minLength znaków';
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
    try {
      await ref
          .read(authRepositoryProvider)
          .register(
            RegisterData(
              firstName: _firstName.text,
              lastName: _lastName.text,
              nickname: _nickname.text,
              login: _login.text,
              password: _password.text,
              phoneNumber: _phone.text,
              unitType: _unitType,
              unitName: _unitName.text,
              voivodeship: _voivodeship,
              county: _county,
              inviteCode: _inviteCode.text,
              adminNotes: _adminNotes.text,
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
}
