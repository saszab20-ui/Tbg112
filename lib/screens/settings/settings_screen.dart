import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tarnobrzeg112/core/app_constants.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/glass_panel.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      title: 'Ustawienia',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const GlassPanel(child: Text(AppConstants.safetyNotice)),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              value: true,
              onChanged: (_) {},
              title: const Text('Powiadomienia push'),
              subtitle: const Text('Kanał FCM i powiadomienia lokalne'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_reset),
              title: const Text('Zmień hasło'),
              onTap: () => context.go(RoutePaths.changePassword),
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
