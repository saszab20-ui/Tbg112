import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';
import 'package:tarnobrzeg112/providers/navigation_providers.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
import 'package:tarnobrzeg112/services/local_preferences.dart';
import 'package:tarnobrzeg112/widgets/app_background.dart';
import 'package:tarnobrzeg112/widgets/glass_panel.dart';
import 'package:tarnobrzeg112/widgets/tbg_logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.redirectRoute});

  final String? redirectRoute;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _rememberLogin = true;
  bool _autoLoginTried = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRememberedLogin());
  }

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
                          const SizedBox(height: 8),
                          CheckboxListTile(
                            value: _rememberLogin,
                            onChanged: (value) =>
                                setState(() => _rememberLogin = value ?? true),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: const Text('Zapamiętaj logowanie'),
                            subtitle: const Text(
                              'Na WWW sesja zostaje zapamiętana przez Firebase.',
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
      await _storeRememberedLogin();
      if (!mounted) return;
      ref.invalidate(authStateProvider);
      ref.invalidate(currentAppUserProvider);
      final pendingRoute = ref.read(pendingNavigationRouteProvider);
      final targetRoute = pendingRoute ?? _redirectRouteFromUrl();
      if (targetRoute != null) {
        ref.read(pendingNavigationRouteProvider.notifier).state = targetRoute;
        debugPrint('AUTH DEBUG pending redirect=$targetRoute');
      }
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

  Future<void> _loadRememberedLogin() async {
    if (_autoLoginTried || _loading) return;
    _autoLoginTried = true;
    final prefs = await loadLocalPreferences();
    final remember = prefs.getBool('auth.rememberLogin') ?? true;
    final login = prefs.getString('auth.login') ?? '';
    final password = prefs.getString('auth.password') ?? '';
    if (!mounted) return;
    setState(() {
      _rememberLogin = remember;
      _login.text = login;
      _password.text = password;
    });
    if (remember && login.isNotEmpty && password.isNotEmpty) {
      await _submit();
    }
  }

  Future<void> _storeRememberedLogin() async {
    final prefs = await loadLocalPreferences();
    await prefs.setBool('auth.rememberLogin', _rememberLogin);
    if (_rememberLogin) {
      await prefs.setString('auth.login', _login.text.trim());
      await prefs.setString('auth.password', _password.text);
    } else {
      await prefs.remove('auth.login');
      await prefs.remove('auth.password');
    }
  }

  String _errorMessage(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' => 'Nieprawidłowy login lub hasło',
        'network-request-failed' =>
          'Brak połączenia z internetem. Spróbuj ponownie.',
        _ => 'Nie udało się zalogować. Spróbuj ponownie.',
      };
    }
    final message = error.toString();
    if (message.contains('invalid-credential') ||
        message.contains('wrong-password') ||
        message.contains('user-not-found')) {
      return 'Nieprawidłowy login lub hasło';
    }
    if (message.contains('Nie znaleziono profilu Firestore dla UID')) {
      return message.replaceFirst('Bad state: ', '');
    }
    return 'Nie udało się zalogować. Spróbuj ponownie.';
  }

  String? _redirectRouteFromUrl() {
    final route = widget.redirectRoute ?? Uri.base.queryParameters['redirect'];
    if (route == null || route.trim().isEmpty) return null;
    if (!route.startsWith('/')) return null;
    return route;
  }
}
