import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tarnobrzeg112/chat/chat_view.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
import 'package:tarnobrzeg112/utils/text_utils.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/empty_state.dart';

class UnitChatScreen extends ConsumerWidget {
  const UnitChatScreen({required this.unitId, super.key});

  final String unitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAppUserProvider).asData?.value;
    if (user == null) {
      return const AppScaffold(
        title: 'Kanał jednostki',
        currentIndex: 1,
        showBackButton: true,
        fallbackRoute: RoutePaths.chats,
        body: EmptyState(
          icon: Icons.lock_outline,
          title: 'Brak dostępu',
          message: 'Sesja użytkownika nie jest aktywna.',
        ),
      );
    }
    final normalizedUnitId = TextUtils.normalizeId(unitId);
    final allowed = user.isAdmin || user.unitId == normalizedUnitId;
    final title = user.unitId == normalizedUnitId
        ? user.unitName
        : _prettyUnitName(normalizedUnitId);
    return AppScaffold(
      title: allowed ? title : 'Kanał jednostki',
      currentIndex: 1,
      showBackButton: true,
      fallbackRoute: RoutePaths.chats,
      actions: allowed
          ? [
              IconButton(
                tooltip: 'Ustawienia czatu',
                onPressed: () => context.go(
                  RoutePaths.chatSettings(
                    TextUtils.unitChatId(normalizedUnitId),
                  ),
                ),
                icon: const Icon(Icons.tune_outlined),
              ),
            ]
          : const [],
      body: allowed
          ? ChatView(scope: ChatScope.unit, chatId: normalizedUnitId)
          : const EmptyState(
              icon: Icons.lock_outline,
              title: 'Brak dostępu',
              message: 'Kanał jest widoczny tylko dla członków jednostki.',
            ),
    );
  }

  String _prettyUnitName(String value) {
    return value
        .split('-')
        .where((part) => part.isNotEmpty)
        .map((part) => part.length <= 3 ? part.toUpperCase() : _title(part))
        .join(' ');
  }

  String _title(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}
