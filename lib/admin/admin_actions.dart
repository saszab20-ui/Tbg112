import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
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

  static Future<void> deleteUser(
    WidgetRef ref,
    BuildContext context,
    AppUser target,
  ) async {
    final actor = ref.read(currentAppUserProvider).asData?.value;
    if (actor == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usunąć użytkownika?'),
        content: Text(
          'Profil ${target.publicName} zostanie zarchiwizowany i usunięty '
          'z grup oraz czatów. Tej operacji nie wykonuj przypadkowo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Usuń użytkownika'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(moderationRepositoryProvider)
          .archiveUser(actor: actor, target: target);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Użytkownik został zarchiwizowany.')),
        );
      }
    } on Object catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  static Future<void> resetPassword(
    WidgetRef ref,
    BuildContext context,
    AppUser target,
  ) async {
    final actor = ref.read(currentAppUserProvider).asData?.value;
    if (actor == null) return;
    final temporaryPassword = _temporaryPassword();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset hasła'),
        content: Text(
          'Użytkownik ${target.publicName} otrzyma hasło tymczasowe:\n\n'
          '$temporaryPassword\n\nPo zalogowaniu aplikacja wymusi zmianę hasła.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Resetuj hasło'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(firestoreProvider)
          .collection('password_reset_requests')
          .add({
            'targetUid': target.uid,
            'targetUserLogin': target.login,
            'temporaryPassword': temporaryPassword,
            'createdBy': actor.uid,
            'createdByLogin': actor.login,
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'pending',
          });
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Hasło zresetowane'),
          content: SelectableText(
            'Login: ${target.login}\nHasło tymczasowe: $temporaryPassword',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zamknij'),
            ),
          ],
        ),
      );
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

  static String _temporaryPassword() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#%';
    final random = Random.secure();
    final body = List.generate(
      12,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
    return 'Tbg112-$body';
  }
}
