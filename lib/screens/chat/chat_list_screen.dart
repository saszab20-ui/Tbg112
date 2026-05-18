import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/providers/chat_providers.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
import 'package:tarnobrzeg112/themes/app_colors.dart';
import 'package:tarnobrzeg112/utils/error_utils.dart';
import 'package:tarnobrzeg112/utils/text_utils.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/empty_state.dart';
import 'package:tarnobrzeg112/widgets/loading_shimmer.dart';

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

    final unitNames = ref.watch(activeUnitNamesProvider);
    final groups = ref.watch(groupChatsProvider(user.uid));

    return AppScaffold(
      title: 'Czaty',
      currentIndex: 1,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(RoutePaths.createGroupChat),
        icon: const Icon(Icons.group_add_outlined),
        label: const Text('Utwórz czat grupowy'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _ChatTile(
            icon: Icons.forum,
            title: 'Czat główny',
            subtitle: 'Widoczny dla wszystkich aktywnych użytkowników',
            onTap: () => context.go(RoutePaths.globalChat),
          ),
          if (!user.isAdmin) ...[
            if (!user.hasUnitChatAccess)
              const EmptyState(
                icon: Icons.apartment_outlined,
                title: 'Brak czatu jednostki',
                message:
                    'Ten typ konta widzi czat główny oraz grupy, do których został dodany.',
              )
            else
              _ChatTile(
                icon: Icons.groups_2,
                title: 'Czat jednostki: ${user.unitName}',
                subtitle: 'Tylko członkowie Twojej jednostki',
                onTap: () => context.go(RoutePaths.unitChat(user.unitId)),
              ),
          ],
          if (user.isAdmin)
            unitNames.when(
              loading: () => LoadingShimmer(
                timeoutTitle: 'Brak czatów jednostek',
                timeoutMessage: 'Nie znaleziono jeszcze jednostek.',
                onRefresh: () => ref.invalidate(activeUnitNamesProvider),
              ),
              error: (error, _) => EmptyState(
                icon: Icons.cloud_off,
                title: 'Nie można pobrać jednostek',
                message: ErrorUtils.readable(error),
                actionLabel: 'Odśwież',
                onAction: () => ref.invalidate(activeUnitNamesProvider),
              ),
              data: (names) {
                final visibleNames = {
                  ...names,
                  if (user.unitName.trim().isNotEmpty) user.unitName.trim(),
                }.toList()..sort();
                if (visibleNames.isEmpty) {
                  return const EmptyState(
                    icon: Icons.apartment_outlined,
                    title: 'Brak czatów jednostek',
                    message:
                        'Jednostki pojawią się po akceptacji użytkowników.',
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('Wszystkie czaty jednostek'),
                    for (final name in visibleNames)
                      _ChatTile(
                        icon: Icons.apartment_outlined,
                        title: name,
                        subtitle: 'Czat jednostki',
                        onTap: () => context.go(
                          RoutePaths.unitChat(TextUtils.normalizeId(name)),
                        ),
                      ),
                  ],
                );
              },
            ),
          _ChatTile(
            icon: Icons.lock,
            title: 'Prywatne rozmowy',
            subtitle: 'Rozmowy 1:1',
            onTap: () => context.go(RoutePaths.privateChats),
          ),
          groups.when(
            loading: () => LoadingShimmer(
              timeoutTitle: 'Nie znaleziono czatów',
              timeoutMessage: 'Nie masz jeszcze czatów grupowych.',
              onRefresh: () => ref.invalidate(groupChatsProvider(user.uid)),
            ),
            error: (error, _) => EmptyState(
              icon: Icons.cloud_off,
              title: 'Nie można pobrać grup',
              message: ErrorUtils.readable(error),
              actionLabel: 'Odśwież',
              onAction: () => ref.invalidate(groupChatsProvider(user.uid)),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const EmptyState(
                  icon: Icons.forum_outlined,
                  title: 'Brak czatów grupowych',
                  message: 'Utwórz grupę i dodaj osoby z różnych jednostek.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(
                    user.isAdmin ? 'Wszystkie grupy' : 'Moje grupy',
                  ),
                  for (final chat in items)
                    _ChatTile(
                      icon: Icons.groups_3_outlined,
                      title: chat.displayNameFor(user.uid),
                      subtitle: '${chat.participantIds.length} uczestników',
                      onTap: () => context.go(RoutePaths.privateChat(chat.id)),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.orange,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
