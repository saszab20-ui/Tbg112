import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:tarnobrzeg112/providers/settings_providers.dart';
import 'package:tarnobrzeg112/themes/app_colors.dart';
import 'package:tarnobrzeg112/utils/error_utils.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/empty_state.dart';
import 'package:tarnobrzeg112/widgets/glass_panel.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';

class PushNotificationsScreen extends ConsumerStatefulWidget {
  const PushNotificationsScreen({super.key});

  @override
  ConsumerState<PushNotificationsScreen> createState() => _PushNotificationsScreenState();
}

class _PushNotificationsScreenState extends ConsumerState<PushNotificationsScreen> {
  bool _requestingPermission = false;
  NotificationSettings? _settings;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (mounted) {
      setState(() => _settings = settings);
    }
  }

  Future<void> _requestPermission() async {
    setState(() => _requestingPermission = true);
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (mounted) {
        setState(() => _settings = settings);
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd uprawnień: ${ErrorUtils.readable(error)}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _requestingPermission = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentAppUserProvider).asData?.value;
    if (user == null) {
      return const AppScaffold(
        title: 'Powiadomienia',
        showBackButton: true,
        body: EmptyState(
          icon: Icons.lock_outline,
          title: 'Brak sesji',
          message: 'Zaloguj się ponownie.',
        ),
      );
    }

    return AppScaffold(
      title: 'Powiadomienia Push',
      showBackButton: true,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusCard(
            settings: _settings,
            loading: _requestingPermission,
            onRequest: _requestPermission,
          ),
          const SizedBox(height: 16),
          const _FCMTokenCard(),
          const SizedBox(height: 16),
          _SettingsSection(user: user),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.settings,
    required this.loading,
    required this.onRequest,
  });

  final NotificationSettings? settings;
  final bool loading;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final status = settings?.authorizationStatus;
    final enabled = status == AuthorizationStatus.authorized ||
                    status == AuthorizationStatus.provisional;

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                enabled ? Icons.check_circle : Icons.warning_amber_rounded,
                color: enabled ? AppColors.green : AppColors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                enabled ? 'Powiadomienia są włączone' : 'Powiadomienia są wyłączone',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            enabled
              ? 'Otrzymujesz ważne informacje o akcjach i wiadomościach.'
              : 'Aby otrzymywać powiadomienia, musisz przyznać uprawnienia w systemie.',
            style: const TextStyle(color: AppColors.muted),
          ),
          if (!enabled) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: loading ? null : onRequest,
              icon: loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.notifications_active_outlined),
              label: const Text('Włącz powiadomienia'),
            ),
          ],
        ],
      ),
    );
  }
}

class _FCMTokenCard extends ConsumerWidget {
  const _FCMTokenCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String?>(
      future: FirebaseMessaging.instance.getToken(),
      builder: (context, snapshot) {
        final token = snapshot.data;
        return Card(
          child: ListTile(
            leading: const Icon(Icons.key_outlined),
            title: const Text('Token FCM'),
            subtitle: Text(
              token ?? (snapshot.connectionState == ConnectionState.waiting ? 'Pobieranie...' : 'Brak tokena'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: token != null
              ? IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: token));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Token skopiowany do schowka')),
                    );
                  },
                )
              : null,
          ),
        );
      },
    );
  }
}

class _SettingsSection extends ConsumerWidget {
  const _SettingsSection({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            'Ustawienia kanałów',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Card(
          child: SwitchListTile(
            value: ref.watch(newAccountSoundsEnabledProvider),
            onChanged: user.isAdmin ? (value) {
              ref.read(newAccountSoundsEnabledProvider.notifier).state = value;
              // Here logic to save this globally if needed
            } : null,
            title: const Text('Nowe konta'),
            subtitle: const Text('Powiadomienia o oczekujących na akceptację (Admin)'),
          ),
        ),
        const Card(
          child: ListTile(
            title: Text('Wiadomości prywatne'),
            subtitle: Text('Zawsze głośne powiadomienia'),
            trailing: Icon(Icons.check, color: AppColors.green),
          ),
        ),
        const Card(
          child: ListTile(
            title: Text('Czat główny'),
            subtitle: Text('Dźwięk zależny od ustawień czatu'),
            trailing: Icon(Icons.volume_up_outlined),
          ),
        ),
      ],
    );
  }
}
