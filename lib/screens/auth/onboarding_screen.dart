import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:tarnobrzeg112/core/app_constants.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
import 'package:tarnobrzeg112/widgets/app_background.dart';
import 'package:tarnobrzeg112/widgets/glass_panel.dart';
import 'package:tarnobrzeg112/widgets/tbg_logo.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 24),
              const TbgLogo(size: 72),
              const SizedBox(height: 28),
              Text(
                'Centrum łączności społeczności ratowniczej',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(AppConstants.safetyNotice),
              const SizedBox(height: 24),
              const GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Point(Icons.forum, 'Czaty główne, jednostek i 1:1'),
                    _Point(Icons.verified_user, 'Akceptacja kont przez admina'),
                    _Point(Icons.push_pin, 'Przypięte komunikaty i moderacja'),
                    _Point(Icons.notifications, 'Powiadomienia push FCM'),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: () => context.go(RoutePaths.login),
                icon: const Icon(Icons.login),
                label: const Text('Zaloguj'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => context.go(RoutePaths.register),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Utwórz konto'),
              ),
            ],
          ).animate().fadeIn(duration: 300.ms),
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
