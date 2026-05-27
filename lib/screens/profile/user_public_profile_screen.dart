import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
import 'package:tarnobrzeg112/themes/app_colors.dart';
import 'package:tarnobrzeg112/utils/error_utils.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/empty_state.dart';
import 'package:tarnobrzeg112/widgets/loading_shimmer.dart';
import 'package:tarnobrzeg112/widgets/status_chips.dart';
import 'package:tarnobrzeg112/widgets/user_avatar.dart';

final userProfileProvider = StreamProvider.family<AppUser?, String>((ref, uid) {
  if (uid.trim().isEmpty) return Stream.value(null);
  return ref.watch(usersRepositoryProvider).watchUser(uid);
});

class UserPublicProfileScreen extends ConsumerWidget {
  const UserPublicProfileScreen({required this.uid, super.key});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider(uid));
    return AppScaffold(
      title: 'Profil użytkownika',
      body: userAsync.when(
        loading: () => const LoadingShimmer(
          timeoutTitle: 'Nie znaleziono profilu',
          timeoutMessage: 'Profil użytkownika nie załadował się.',
        ),
        error: (_, _) => const EmptyState(
          icon: Icons.person_off_outlined,
          title: 'Nie można pobrać profilu',
          message: 'Spróbuj ponownie za chwilę.',
        ),
        data: (user) {
          if (user == null) {
            return const EmptyState(
              icon: Icons.person_off_outlined,
              title: 'Brak profilu',
              message: 'Nie znaleziono takiego użytkownika.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  UserAvatar(user: user, radius: 34),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.nickname.trim().isEmpty
                              ? user.publicName
                              : user.nickname,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.unitName.trim().isEmpty
                              ? user.unitType.label
                              : '${user.unitType.label} · ${user.unitName}',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  RoleBadge(user.role),
                  AccountStatusBadge(user.accountStatus),
                  UnitBadge(type: user.unitType, name: user.unitName),
                ],
              ),
              const SizedBox(height: 16),
              _ProfileActions(user: user),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileActions extends ConsumerWidget {
  const _ProfileActions({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentAppUserProvider).asData?.value;
    if (current == null || current.uid == user.uid) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _openPrivateChat(context, ref, current),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Prywatna wiadomość'),
          ),
        ),
        if (user.isModerator) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push(RoutePaths.reports),
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('Prośby'),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openPrivateChat(
    BuildContext context,
    WidgetRef ref,
    AppUser current,
  ) async {
    try {
      final chatId = await ref
          .read(privateChatRepositoryProvider)
          .openChat(current, user);
      if (context.mounted) context.go(RoutePaths.privateChat(chatId));
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Nie udało się utworzyć rozmowy. ${ErrorUtils.readable(error)}',
          ),
        ),
      );
    }
  }
}
