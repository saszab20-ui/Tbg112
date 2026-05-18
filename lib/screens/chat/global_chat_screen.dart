import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tarnobrzeg112/chat/chat_view.dart';
import 'package:tarnobrzeg112/core/app_constants.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';

class GlobalChatScreen extends StatelessWidget {
  const GlobalChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Czat główny',
      currentIndex: 1,
      showBackButton: true,
      fallbackRoute: RoutePaths.chats,
      actions: [
        IconButton(
          tooltip: 'Ustawienia czatu',
          onPressed: () =>
              context.go(RoutePaths.chatSettings(AppConstants.globalChatId)),
          icon: const Icon(Icons.tune_outlined),
        ),
      ],
      body: const ChatView(
        scope: ChatScope.global,
        chatId: AppConstants.globalChatId,
      ),
    );
  }
}
