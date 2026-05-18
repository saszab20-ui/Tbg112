import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
import 'package:tarnobrzeg112/utils/error_utils.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/empty_state.dart';
import 'package:tarnobrzeg112/widgets/loading_shimmer.dart';

class InviteJoinScreen extends ConsumerStatefulWidget {
  const InviteJoinScreen({required this.inviteCode, super.key});

  final String inviteCode;

  @override
  ConsumerState<InviteJoinScreen> createState() => _InviteJoinScreenState();
}

class _InviteJoinScreenState extends ConsumerState<InviteJoinScreen> {
  Future<String>? _joinFuture;

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(currentAppUserProvider);
    return AppScaffold(
      title: 'Zaproszenie do czatu',
      showBackButton: true,
      fallbackRoute: RoutePaths.chats,
      body: userState.when(
        loading: () => const LoadingShimmer(
          timeoutTitle: 'Nie można dołączyć',
          timeoutMessage: 'Profil użytkownika nie został jeszcze załadowany.',
        ),
        error: (error, _) => EmptyState(
          icon: Icons.cloud_off,
          title: 'Nie można pobrać profilu',
          message: ErrorUtils.readable(error),
          actionLabel: 'Odśwież',
          onAction: () => ref.invalidate(currentAppUserProvider),
        ),
        data: (user) {
          if (user == null) {
            return const EmptyState(
              icon: Icons.lock_outline,
              title: 'Brak sesji',
              message: 'Zaloguj się, aby dołączyć do czatu.',
            );
          }
          _joinFuture ??= ref
              .read(privateChatRepositoryProvider)
              .joinByInvite(inviteCode: widget.inviteCode, user: user);
          return FutureBuilder<String>(
            future: _joinFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LoadingShimmer(
                  timeoutTitle: 'Dołączanie trwa',
                  timeoutMessage: 'Sprawdzamy link zaproszenia.',
                );
              }
              if (snapshot.hasError) {
                return EmptyState(
                  icon: Icons.link_off,
                  title: 'Nie można dołączyć do czatu',
                  message: ErrorUtils.readable(snapshot.error!),
                  actionLabel: 'Spróbuj ponownie',
                  onAction: () {
                    setState(() => _joinFuture = null);
                  },
                );
              }
              final chatId = snapshot.data ?? '';
              return EmptyState(
                icon: Icons.check_circle_outline,
                title: 'Dołączono do czatu',
                message: 'Możesz już przejść do rozmowy grupowej.',
                actionLabel: 'Otwórz czat',
                onAction: () => context.go(RoutePaths.privateChat(chatId)),
              );
            },
          );
        },
      ),
    );
  }
}
