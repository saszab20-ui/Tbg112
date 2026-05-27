import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tarnobrzeg112/chat/chat_view.dart';
import 'package:tarnobrzeg112/core/app_constants.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/providers/service_mode_provider.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
import 'package:tarnobrzeg112/utils/text_utils.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/empty_state.dart';

class UnitChatScreen extends ConsumerWidget {
  const UnitChatScreen({
    required this.unitId,
    this.servicePreview = false,
    super.key,
  });

  final String unitId;
  final bool servicePreview;

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
    final normalizedUnitId = _normalizeUnitId(unitId);
    final serviceReadOnly =
        servicePreview &&
        isServiceModeActive(ref.watch(serviceModeExpiresAtProvider)) &&
        user.isAdmin &&
        user.login == AppConstants.superAdminLogin;
    final serviceChannelAllowed = _canOpenServiceChannel(
      user,
      normalizedUnitId,
    );
    final allowed =
        user.unitId == normalizedUnitId ||
        serviceChannelAllowed ||
        serviceReadOnly;
    final title = user.unitId == normalizedUnitId
        ? user.unitName
        : _prettyUnitName(normalizedUnitId);
    return AppScaffold(
      title: allowed
          ? (serviceReadOnly ? 'Podgląd: $title' : title)
          : 'Kanał jednostki',
      currentIndex: 1,
      showBackButton: true,
      fallbackRoute: serviceReadOnly
          ? RoutePaths.adminServiceMode
          : RoutePaths.chats,
      actions: allowed && !serviceReadOnly
          ? [
              IconButton(
                tooltip: 'Ustawienia czatu',
                onPressed: () => context.push(
                  RoutePaths.chatSettings(
                    TextUtils.unitChatId(normalizedUnitId),
                  ),
                ),
                icon: const Icon(Icons.tune_outlined),
              ),
            ]
          : const [],
      body: allowed
          ? ChatView(
              scope: ChatScope.unit,
              chatId: normalizedUnitId,
              readOnly: serviceReadOnly,
            )
          : const EmptyState(
              icon: Icons.lock_outline,
              title: 'Brak dostępu',
              message: 'Kanał jest widoczny tylko dla członków jednostki.',
            ),
    );
  }

  String _prettyUnitName(String value) {
    if (value == 'service_psp') return 'PSP';
    if (value == 'service_policja') return 'Policja';
    if (value == 'service_medycy') return 'Medycy';
    if (value == 'service_media') return 'Media';
    return value
        .split('-')
        .expand((part) => part.split('_'))
        .where((part) => part.isNotEmpty)
        .map((part) => part.length <= 3 ? part.toUpperCase() : _title(part))
        .join(' ');
  }

  bool _canOpenServiceChannel(AppUser user, String normalizedUnitId) {
    if (user.isAdmin) {
      return _isServiceChannel(normalizedUnitId);
    }
    if (user.role == UserRole.moderator) {
      return switch (normalizedUnitId) {
        'service_psp' => user.moderatorPermissions['channelPsp'] == true,
        'service_policja' =>
          user.moderatorPermissions['channelPolicja'] == true,
        'service_medycy' => user.moderatorPermissions['channelMedycy'] == true,
        'service_media' => user.moderatorPermissions['channelMedia'] == true,
        _ => false,
      };
    }
    return switch (normalizedUnitId) {
      'service_psp' => user.unitType == UnitType.psp,
      'service_policja' => user.unitType == UnitType.policja,
      'service_medycy' =>
        user.unitType == UnitType.zrm ||
            user.unitType == UnitType.ratownikMedyczny ||
            user.unitType == UnitType.kierowcaKaretki ||
            user.unitType == UnitType.dyspozytor,
      'service_media' => user.unitType == UnitType.media,
      _ => false,
    };
  }

  String _normalizeUnitId(String value) {
    final clean = value.trim();
    if (_isServiceChannel(clean)) return clean;
    return TextUtils.normalizeId(clean);
  }

  bool _isServiceChannel(String value) {
    return value == 'service_psp' ||
        value == 'service_policja' ||
        value == 'service_medycy' ||
        value == 'service_media';
  }

  String _title(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}
