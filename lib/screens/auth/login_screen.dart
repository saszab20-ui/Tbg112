import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';
import 'package:tarnobrzeg112/repositories/auth_repository.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
import 'package:tarnobrzeg112/utils/text_utils.dart';
import 'package:tarnobrzeg112/widgets/app_background.dart';
import 'package:tarnobrzeg112/widgets/glass_panel.dart';
import 'package:tarnobrzeg112/widgets/tbg_logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: ListView(
                padding: const EdgeInsets.all(20),
                shrinkWrap: true,
                children: [
                  const TbgLogo(size: 64),
                  const SizedBox(height: 24),
                  GlassPanel(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Logowanie',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: _login,
                            decoration: const InputDecoration(
                              labelText: 'Login',
                              prefixIcon: Icon(Icons.account_circle_outlined),
                            ),
                            validator: _required,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Hasło',
                              prefixIcon: const Icon(Icons.lock_outline),
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
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            validator: _passwordValidator,
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
                                : const Icon(Icons.login),
                            label: const Text('Wejdź'),
                          ),
                          TextButton(
                            onPressed: () =>
                                context.go(RoutePaths.forgotPassword),
                            child: const Text('Nie pamiętam hasła'),
                          ),
                          OutlinedButton(
                            onPressed: () => context.go(RoutePaths.register),
                            child: const Text('Rejestracja'),
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

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Uzupełnij pole';
    return null;
  }

  String? _passwordValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Uzupełnij pole';
    if (text.length < 6) return 'Minimum 6 znaków';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(login: _login.text, password: _password.text);
      if (!mounted) return;
      ref.invalidate(authStateProvider);
      ref.invalidate(currentAppUserProvider);
      context.go(RoutePaths.loading);
    } on Object catch (error) {
      if (!mounted) return;
      final currentUser = ref.read(authRepositoryProvider).currentUser;
      if (currentUser != null) {
        ref.invalidate(authStateProvider);
        ref.invalidate(currentAppUserProvider);
        context.go(RoutePaths.loading);
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _errorMessage(Object error) {
    final normalizedLogin = TextUtils.normalizeLogin(_login.text);
    final authEmail = AuthRepository.technicalEmailForLogin(normalizedLogin);
    if (error is FirebaseAuthException) {
      return 'Nie udało się zalogować. authEmail=$authEmail Firebase UID=- '
          'accountStatus=- role=- FirebaseAuthException.code=${error.code}';
    }
    final message = error.toString();
    if (message.contains('invalid-credential') ||
        message.contains('wrong-password')) {
      return 'Nie udało się zalogować: nieprawidłowy login lub hasło. '
          'authEmail=$authEmail Firebase UID=- accountStatus=- role=- '
          'FirebaseAuthException.code=invalid-credential';
    }
    if (message.contains('user-not-found')) {
      return 'Nie udało się zalogować: konto nie istnieje w Firebase Auth. '
          'authEmail=$authEmail Firebase UID=- accountStatus=- role=- '
          'FirebaseAuthException.code=user-not-found';
    }
    if (message.contains('Nie znaleziono profilu Firestore dla UID')) {
      return message.replaceFirst('Bad state: ', '');
    }
    return 'Nie udało się zalogować: ${message.replaceFirst('Bad state: ', '')}';
  }
}
