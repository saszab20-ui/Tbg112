import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tarnobrzeg112/providers/chat_providers.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
import 'package:tarnobrzeg112/themes/app_colors.dart';
import 'package:tarnobrzeg112/widgets/app_background.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.title,
    required this.body,
    super.key,
    this.actions = const [],
    this.currentIndex,
    this.floatingActionButton,
    this.showBackButton,
    this.fallbackRoute = RoutePaths.home,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final int? currentIndex;
  final Widget? floatingActionButton;
  final bool? showBackButton;
  final String fallbackRoute;

  bool get _hasBackButton => showBackButton ?? currentIndex == null;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack(context);
      },
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            leading: _hasBackButton
                ? IconButton(
                    tooltip: 'Wstecz',
                    onPressed: () => _handleBack(context),
                    icon: const Icon(Icons.arrow_back),
                  )
                : null,
            title: Text(title, overflow: TextOverflow.ellipsis),
            actions: actions,
          ),
          body: SafeArea(child: body),
          floatingActionButton: floatingActionButton,
          bottomNavigationBar: currentIndex == null
              ? null
              : _BottomNav(currentIndex!),
        ),
      ),
    );
  }

  void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    if (_hasBackButton) {
      context.go(fallbackRoute);
      return;
    }
    if (currentIndex != null) {
      if (currentIndex != 1) {
        context.go(RoutePaths.chats);
      }
      return;
    }
  }
}

class _BottomNav extends ConsumerWidget {
  const _BottomNav(this.currentIndex);

  final int currentIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final privateUnread = ref.watch(privateUnreadTotalProvider);
    final chatUnread = ref.watch(chatUnreadTotalProvider);
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        final location = switch (index) {
          0 => RoutePaths.home,
          1 => RoutePaths.chats,
          2 => RoutePaths.privateChats,
          3 => RoutePaths.notifications,
          _ => RoutePaths.profile,
        };
        context.go(location);
      },
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard, color: AppColors.red),
          label: 'Start',
        ),
        NavigationDestination(
          icon: chatUnread > 0
              ? Badge(
                  label: Text(_badgeText(chatUnread)),
                  child: const Icon(Icons.forum_outlined),
                )
              : const Icon(Icons.forum_outlined),
          selectedIcon: chatUnread > 0
              ? Badge(
                  label: Text(_badgeText(chatUnread)),
                  child: const Icon(Icons.forum, color: AppColors.red),
                )
              : const Icon(Icons.forum, color: AppColors.red),
          label: 'Czat',
        ),
        NavigationDestination(
          icon: privateUnread > 0
              ? Badge(
                  label: Text(_badgeText(privateUnread)),
                  child: Icon(Icons.lock_outline),
                )
              : const Icon(Icons.lock_outline),
          selectedIcon: privateUnread > 0
              ? Badge(
                  label: Text(_badgeText(privateUnread)),
                  child: const Icon(Icons.lock, color: AppColors.red),
                )
              : const Icon(Icons.lock, color: AppColors.red),
          label: 'Prywatne',
        ),
        const NavigationDestination(
          icon: Icon(Icons.notifications_none),
          selectedIcon: Icon(Icons.notifications, color: AppColors.red),
          label: 'Info',
        ),
        const NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person, color: AppColors.red),
          label: 'Profil',
        ),
      ],
    );
  }

  String _badgeText(int count) => count > 99 ? '99+' : '$count';
}
