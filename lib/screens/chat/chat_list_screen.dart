import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/providers/chat_providers.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/empty_state.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAppUserProvider).asData?.value;
    if (user == null) {
      return const AppScaffold(
        title: 'Czaty',
        currentIndex: 1,
        body: EmptyState(
          icon: Icons.lock_outline,
          title: 'Brak sesji',
          message: 'Zaloguj się ponownie.',
        ),
      );
    }

    final mainUnread = ref.watch(
      chatUnreadCountProvider(
        ChatReadQuery(scope: ChatScope.global, chatId: 'main', uid: user.uid),
      ),
    );
    final ownUnitUnread = user.hasUnitChatAccess
        ? ref.watch(
            chatUnreadCountProvider(
              ChatReadQuery(
                scope: ChatScope.unit,
                chatId: user.unitId,
                uid: user.uid,
              ),
            ),
          )
        : 0;

    return AppScaffold(
      title: 'Czaty',
      currentIndex: 1,
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _ChatTile(
            icon: Icons.forum,
            title: 'Czat główny',
            subtitle: 'Widoczny dla aktywnych użytkowników',
            badgeCount: mainUnread,
            onTap: () => context.go(RoutePaths.globalChat),
          ),
          if (user.hasUnitChatAccess)
            _ChatTile(
              icon: Icons.groups_2,
              title: 'Czat jednostki: ${user.unitName}',
              subtitle: 'Tylko członkowie Twojej jednostki',
              badgeCount: ownUnitUnread,
              onTap: () => context.go(RoutePaths.unitChat(user.unitId)),
            ),
          for (final service in _visibleServiceCards(user))
            _ChatTile(
              icon: service.icon,
              title: service.title,
              subtitle: service.subtitle,
              onTap: () => context.go(RoutePaths.unitChat(service.chatId)),
            ),
        ],
      ),
    );
  }

  List<_ServiceChatCard> _visibleServiceCards(AppUser user) {
    final cards = <_ServiceChatCard>[];
    if (_hasServiceChannelAccess(
      user,
      permissionKey: 'channelPsp',
      unitMatch: user.unitType == UnitType.psp,
    )) {
      cards.add(
        const _ServiceChatCard(
          chatId: 'service_psp',
          title: 'PSP',
          subtitle: 'Kanał służbowy PSP',
          icon: Icons.local_fire_department_outlined,
        ),
      );
    }
    if (_hasServiceChannelAccess(
      user,
      permissionKey: 'channelPolicja',
      unitMatch: user.unitType == UnitType.policja,
    )) {
      cards.add(
        const _ServiceChatCard(
          chatId: 'service_policja',
          title: 'Policja',
          subtitle: 'Kanał służbowy Policji',
          icon: Icons.local_police_outlined,
        ),
      );
    }
    if (_hasServiceChannelAccess(
      user,
      permissionKey: 'channelMedycy',
      unitMatch:
          user.unitType == UnitType.zrm ||
          user.unitType == UnitType.ratownikMedyczny ||
          user.unitType == UnitType.kierowcaKaretki ||
          user.unitType == UnitType.dyspozytor,
    )) {
      cards.add(
        const _ServiceChatCard(
          chatId: 'service_medycy',
          title: 'Medycy',
          subtitle: 'Kanał ratownictwa medycznego',
          icon: Icons.medical_services_outlined,
        ),
      );
    }
    if (_hasServiceChannelAccess(
      user,
      permissionKey: 'channelMedia',
      unitMatch: user.unitType == UnitType.media,
    )) {
      cards.add(
        const _ServiceChatCard(
          chatId: 'service_media',
          title: 'Media',
          subtitle: 'Kanał informacyjny dla mediów',
          icon: Icons.campaign_outlined,
        ),
      );
    }
    return cards;
  }

  bool _hasServiceChannelAccess(
    AppUser user, {
    required String permissionKey,
    required bool unitMatch,
  }) {
    if (user.isAdmin) return true;
    if (user.role == UserRole.moderator) {
      return user.moderatorPermissions[permissionKey] == true;
    }
    return unitMatch;
  }
}

class _ServiceChatCard {
  const _ServiceChatCard({
    required this.chatId,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String chatId;
  final String title;
  final String subtitle;
  final IconData icon;
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle),
        trailing: badgeCount > 0
            ? Badge(
                label: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
                child: const Icon(Icons.chevron_right),
              )
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
