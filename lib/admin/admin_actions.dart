import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';
import 'package:tarnobrzeg112/utils/error_utils.dart';

class AdminActions {
  const AdminActions._();

  static Future<void> changeStatus(
    WidgetRef ref,
    BuildContext context,
    AppUser target,
    AccountStatus status,
  ) async {
    final actor = ref.read(currentAppUserProvider).asData?.value;
    if (actor == null) return;
    try {
      await ref
          .read(moderationRepositoryProvider)
          .changeAccountStatus(actor: actor, target: target, status: status);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Zmieniono status: ${status.label}')),
        );
      }
    } on Object catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  static Future<void> changeRole(
    WidgetRef ref,
    BuildContext context,
    AppUser target,
    UserRole role,
  ) async {
    final actor = ref.read(currentAppUserProvider).asData?.value;
    if (actor == null) return;
    try {
      await ref
          .read(moderationRepositoryProvider)
          .changeRole(actor: actor, target: target, role: role);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Nadano rolę: ${role.label}')));
      }
    } on Object catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  static Future<void> mute(
    WidgetRef ref,
    BuildContext context,
    AppUser target,
  ) async {
    final actor = ref.read(currentAppUserProvider).asData?.value;
    if (actor == null) return;
    try {
      await ref
          .read(moderationRepositoryProvider)
          .muteUser(
            actor: actor,
            target: target,
            duration: const Duration(hours: 24),
            reason: 'Wyciszenie z panelu administratora',
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Użytkownik wyciszony na 24 godziny.')),
        );
      }
    } on Object catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  static Future<void> unmute(
    WidgetRef ref,
    BuildContext context,
    AppUser target,
  ) async {
    final actor = ref.read(currentAppUserProvider).asData?.value;
    if (actor == null) return;
    try {
      await ref
          .read(moderationRepositoryProvider)
          .unmuteUser(actor: actor, target: target);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Użytkownik odblokowany.')),
        );
      }
    } on Object catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  static void _showError(BuildContext context, Object error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Operacja nie powiodła się: ${ErrorUtils.readable(error)}',
        ),
      ),
    );
  }
}
