import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tarnobrzeg112/core/app_constants.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';
import 'package:tarnobrzeg112/widgets/app_background.dart';
import 'package:tarnobrzeg112/widgets/glass_panel.dart';
import 'package:tarnobrzeg112/widgets/status_chips.dart';
import 'package:tarnobrzeg112/widgets/tbg_logo.dart';

class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAppUserProvider).asData?.value;
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: GlassPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const TbgLogo(size: 64),
                      const SizedBox(height: 20),
                      Text(
                        'Konto wymaga akceptacji',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user == null
                            ? AppConstants.safetyNotice
                            : 'Status: ${user.accountStatus.label}',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      if (user != null) AccountStatusBadge(user.accountStatus),
                      const SizedBox(height: 22),
                      OutlinedButton.icon(
                        onPressed: () => ref
                            .read(authRepositoryProvider)
                            .signOut(reason: 'pending_approval_button'),
                        icon: const Icon(Icons.logout),
                        label: const Text('Wyloguj'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
