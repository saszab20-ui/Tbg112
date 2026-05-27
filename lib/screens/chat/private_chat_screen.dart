import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tarnobrzeg112/chat/chat_view.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/providers/chat_providers.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
import 'package:tarnobrzeg112/utils/error_utils.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/empty_state.dart';
import 'package:tarnobrzeg112/widgets/loading_shimmer.dart';

class PrivateChatScreen extends ConsumerWidget {
  const PrivateChatScreen({required this.chatId, super.key});

  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(privateChatProvider(chatId));
    return chat.when(
      loading: () => const AppScaffold(
        title: 'Rozmowa',
        currentIndex: 2,
        showBackButton: true,
        fallbackRoute: RoutePaths.privateChats,
        body: LoadingShimmer(
          timeoutTitle: 'Brak rozmowy',
          timeoutMessage: 'Nie znaleziono danych rozmowy.',
        ),
      ),
      error: (error, _) => AppScaffold(
        title: 'Rozmowa',
        currentIndex: 2,
        showBackButton: true,
        fallbackRoute: RoutePaths.privateChats,
        body: EmptyState(
          icon: Icons.cloud_off,
          title: 'Nie można pobrać rozmowy',
          message: ErrorUtils.readable(error),
          actionLabel: 'Odśwież',
          onAction: () => ref.invalidate(privateChatProvider(chatId)),
        ),
      ),
      data: (chat) {
        if (chat == null) {
          return const AppScaffold(
            title: 'Rozmowa',
            currentIndex: 2,
            showBackButton: true,
            fallbackRoute: RoutePaths.privateChats,
            body: EmptyState(
              icon: Icons.lock_outline,
              title: 'Brak czatu',
              message: 'Ta rozmowa nie istnieje albo nie masz do niej dostępu.',
            ),
          );
        }
        return AppScaffold(
          title: chat.isGroup ? chat.name : 'Rozmowa prywatna',
          currentIndex: 2,
          showBackButton: true,
          fallbackRoute: RoutePaths.privateChats,
          actions: [
            IconButton(
              tooltip: 'Ustawienia czatu',
              onPressed: () => context.push(RoutePaths.chatSettings(chat.id)),
              icon: const Icon(Icons.tune_outlined),
            ),
          ],
          body: ChatView(
            scope: chat.isGroup ? ChatScope.group : ChatScope.private,
            chatId: chat.id,
          ),
        );
      },
    );
  }
}
