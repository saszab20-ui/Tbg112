import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/glass_panel.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _repeatPassword = TextEditingController();

  bool _loading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureRepeat = true;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _repeatPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Zmień hasło',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassPanel(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Zmień hasło do konta',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _passwordField(
                        controller: _currentPassword,
                        label: 'Stare hasło',
                        obscureText: _obscureCurrent,
                        onToggle: () =>
                            setState(() => _obscureCurrent = !_obscureCurrent),
                      ),
                      const SizedBox(height: 12),
                      _passwordField(
                        controller: _newPassword,
                        label: 'Nowe hasło',
                        obscureText: _obscureNew,
                        onToggle: () =>
                            setState(() => _obscureNew = !_obscureNew),
                      ),
                      const SizedBox(height: 12),
                      _passwordField(
                        controller: _repeatPassword,
                        label: 'Powtórz nowe hasło',
                        obscureText: _obscureRepeat,
                        onToggle: () =>
                            setState(() => _obscureRepeat = !_obscureRepeat),
                        validator: _repeatValidator,
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
                            : const Icon(Icons.lock_reset),
                        label: const Text('Zmień hasło'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextFormField _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: obscureText ? 'Pokaż hasło' : 'Ukryj hasło',
          icon: Icon(
            obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: onToggle,
        ),
      ),
      validator: validator ?? _passwordValidator,
    );
  }

  String? _passwordValidator(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Uzupełnij pole';
    if (text.length < 6) return 'Minimum 6 znaków';
    return null;
  }

  String? _repeatValidator(String? value) {
    final basic = _passwordValidator(value);
    if (basic != null) return basic;
    if (value != _newPassword.text) {
      return 'Nowe hasła muszą być takie same';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final appUser = ref.read(currentAppUserProvider).asData?.value;
    if (appUser == null) {
      _showError('Nie znaleziono aktywnego profilu użytkownika.');
      return;
    }

    setState(() => _loading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .changePassword(
            login: appUser.login,
            currentPassword: _currentPassword.text,
            newPassword: _newPassword.text,
          );
      if (!mounted) return;
      _currentPassword.clear();
      _newPassword.clear();
      _repeatPassword.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Hasło zostało zmienione.')));
    } on Object catch (error) {
      if (!mounted) return;
      _showError(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _errorMessage(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'wrong-password' ||
        'invalid-credential' => 'Stare hasło jest nieprawidłowe.',
        'weak-password' => 'Nowe hasło jest zbyt słabe.',
        'requires-recent-login' =>
          'Sesja wygasła. Wyloguj się, zaloguj ponownie i spróbuj jeszcze raz.',
        _ => 'Nie udało się zmienić hasła: ${error.message ?? error.code}',
      };
    }
    return 'Nie udało się zmienić hasła: ${error.toString().replaceFirst('Bad state: ', '')}';
  }
}
