import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:tarnobrzeg112/core/app_constants.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';
import 'package:tarnobrzeg112/providers/settings_providers.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
import 'package:tarnobrzeg112/services/local_preferences.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/glass_panel.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _newAccountSoundsKey = 'settings.newAccountSounds';
  static const _privacyModeKey = 'settings.privacyMode';

  LocalPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await loadLocalPreferences();
    final firestoreSettings = await _loadFirestoreSettings();
    if (!mounted) return;
    _prefs = prefs;
    ref.read(newAccountSoundsEnabledProvider.notifier).state =
        _boolSetting(firestoreSettings, 'newAccountSounds') ??
        prefs.getBool(_newAccountSoundsKey) ??
        ref.read(newAccountSoundsEnabledProvider);
    ref.read(privacyModeEnabledProvider.notifier).state =
        _boolSetting(firestoreSettings, 'privacyMode') ??
        prefs.getBool(_privacyModeKey) ??
        ref.read(privacyModeEnabledProvider);
  }

  Future<void> _saveBool(
    StateProvider<bool> provider,
    String key,
    bool value,
  ) async {
    ref.read(provider.notifier).state = value;
    await (_prefs ??= await loadLocalPreferences()).setBool(key, value);
    await _saveFirestoreSetting(_settingNameForKey(key), value);
  }

  Future<Map<String, Object?>> _loadFirestoreSettings() async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return const {};
    try {
      final doc = await ref
          .read(firestoreProvider)
          .collection('users')
          .doc(uid)
          .get();
      final settings = doc.data()?['settings'];
      if (settings is Map<String, Object?>) return settings;
      if (settings is Map) return Map<String, Object?>.from(settings);
    } on Object catch (error) {
      debugPrint('SETTINGS DEBUG load failed: $error');
    }
    return const {};
  }

  Future<void> _saveFirestoreSetting(String key, Object value) async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return;
    try {
      await ref.read(firestoreProvider).collection('users').doc(uid).set({
        'settings': {key: value},
        'settingsUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on Object catch (error) {
      debugPrint('SETTINGS DEBUG save failed: $error');
    }
  }

  String _settingNameForKey(String key) {
    return switch (key) {
      _newAccountSoundsKey => 'newAccountSounds',
      _privacyModeKey => 'privacyMode',
      _ => key,
    };
  }

  bool? _boolSetting(Map<String, Object?> settings, String key) {
    final value = settings[key];
    return value is bool ? value : null;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentAppUserProvider).asData?.value;
    return AppScaffold(
      title: 'Ustawienia',
      showBackButton: true,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const GlassPanel(child: Text(AppConstants.safetyNotice)),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.notifications_outlined),
              title: Text('Powiadomienia push'),
              subtitle: Text('Kanał FCM i powiadomienia lokalne'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.tune_outlined),
              title: const Text('Dźwięki i wygląd czatu'),
              subtitle: const Text(
                'Ustawienia dźwięków, wibracji, kolorów i tła przeniesiono do menu ⋮ / ustawień konkretnego czatu.',
              ),
              onTap: () => context.push(RoutePaths.chatSettings('main')),
            ),
          ),
          if (currentUser?.isAdmin == true)
            Card(
              child: SwitchListTile(
                value: ref.watch(newAccountSoundsEnabledProvider),
                onChanged: (value) => _saveBool(
                  newAccountSoundsEnabledProvider,
                  _newAccountSoundsKey,
                  value,
                ),
                secondary: const Icon(Icons.person_add_alt),
                title: const Text('Dźwięki nowych kont'),
                subtitle: const Text(
                  'Sygnał dla kont oczekujących na akceptację',
                ),
              ),
            ),
          if (currentUser?.isAdmin == true)
            Card(
              child: SwitchListTile(
                value: ref.watch(privacyModeEnabledProvider),
                onChanged: (value) => _saveBool(
                  privacyModeEnabledProvider,
                  _privacyModeKey,
                  value,
                ),
                secondary: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Tryb prywatności'),
                subtitle: const Text(
                  'Blokuje zrzuty i nagrywanie ekranu Android',
                ),
              ),
            ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('Samouczek / pierwsza konfiguracja'),
              subtitle: const Text('Kolory, tła, dźwięki i avatar'),
              onTap: () => context.push(RoutePaths.editProfile),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_reset),
              title: const Text('Zmień hasło'),
              onTap: () => context.push(RoutePaths.changePassword),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Wyloguj'),
              onTap: () =>
                  ref.read(authRepositoryProvider).signOut(reason: 'settings'),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Wersja'),
              subtitle: Text('1.0.0 build 1'),
            ),
          ),
        ],
      ),
    );
  }
}
