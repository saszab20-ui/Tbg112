import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tarnobrzeg112/core/app_constants.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
import 'package:tarnobrzeg112/themes/app_colors.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/glass_panel.dart';
import 'package:tarnobrzeg112/widgets/tbg_logo.dart';

class FirstLoginTutorialScreen extends ConsumerWidget {
  const FirstLoginTutorialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAppUserProvider).asData?.value;
    return AppScaffold(
      title: 'Pierwsza konfiguracja',
      showBackButton: false,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(20),
            children: [
              const Center(child: TbgLogo(size: 72)),
              const SizedBox(height: 18),
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Witamy w Tarnobrzeg 112',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Możesz spersonalizować aplikację i dopasować ją do siebie.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 18),
                    const _SetupLine(
                      icon: Icons.palette_outlined,
                      text: 'Ustaw kolor i tło czatu',
                    ),
                    const _SetupLine(
                      icon: Icons.notifications_active_outlined,
                      text: 'Wybierz dźwięk przychodzących wiadomości',
                    ),
                    const _SetupLine(
                      icon: Icons.image_outlined,
                      text: 'Ustaw avatar',
                    ),
                    const _SetupLine(
                      icon: Icons.forum_outlined,
                      text: 'Skonfiguruj wygląd czatów',
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: user == null
                          ? null
                          : () => _finish(
                              context,
                              ref,
                              user.uid,
                              RoutePaths.chatSettings(
                                AppConstants.globalChatId,
                              ),
                              push: true,
                            ),
                      icon: const Icon(Icons.tune),
                      label: const Text('Skonfiguruj teraz'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: user == null
                          ? null
                          : () => _finish(
                              context,
                              ref,
                              user.uid,
                              RoutePaths.chats,
                            ),
                      child: const Text('Pomiń'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _finish(
    BuildContext context,
    WidgetRef ref,
    String uid,
    String route, {
    bool push = false,
  }) async {
    await ref.read(usersRepositoryProvider).completeFirstLoginTutorial(uid);
    ref.invalidate(currentAppUserProvider);
    if (!context.mounted) return;
    if (push) {
      context.push(route);
    } else {
      context.go(route);
    }
  }
}

class _SetupLine extends StatelessWidget {
  const _SetupLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppColors.orange),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
