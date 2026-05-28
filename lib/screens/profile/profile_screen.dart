import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
import 'package:tarnobrzeg112/themes/app_colors.dart';
import 'package:tarnobrzeg112/utils/date_time_utils.dart';
import 'package:tarnobrzeg112/utils/error_utils.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/empty_state.dart';
import 'package:tarnobrzeg112/widgets/glass_panel.dart';
import 'package:tarnobrzeg112/widgets/loading_shimmer.dart';
import 'package:tarnobrzeg112/widgets/status_chips.dart';
import 'package:tarnobrzeg112/widgets/tbg_logo.dart';
import 'package:tarnobrzeg112/widgets/user_avatar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentAppUserProvider);
    return AppScaffold(
      title: 'Profil',
      currentIndex: 4,
      showBackButton: true,
      fallbackRoute: RoutePaths.home,
      actions: [
        IconButton(
          tooltip: 'Edytuj',
          onPressed: () => context.push(RoutePaths.editProfile),
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
      body: userAsync.when(
        loading: () => LoadingShimmer(
          timeoutTitle: 'Brak danych profilu',
          timeoutMessage: 'Profil nie załadował się automatycznie.',
          onRefresh: () => ref.invalidate(currentAppUserProvider),
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
              icon: Icons.person_off_outlined,
              title: 'Brak danych profilu',
              message: 'Nie znaleziono profilu dla aktywnej sesji.',
            );
          }
          return _ProfileContent(user: user);
        },
      ),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kDebugMode) {
      debugPrint(
        'ProfileScreen._ProfileContent.build: uid=${user.uid} '
        'presenceStatus=${user.presenceStatus.name} '
        'isManualStatus=${user.isManualStatus}',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassPanel(
          child: Column(
            children: [
              const TbgLogo(size: 40, showText: false),
              const SizedBox(height: 12),
              UserAvatar(user: user, radius: 46),
              const SizedBox(height: 12),
              Text(
                user.displayName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.unitName.trim().isEmpty
                    ? user.role.label
                    : user.publicName,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  RoleBadge(user.role),
                  AccountStatusBadge(user.accountStatus),
                  UnitBadge(type: user.unitType, name: user.unitName),
                ],
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _showStatusSelector(context, ref, user),
                child: _Info('Status', _presenceLabel(user)),
              ),
              _Info('Login', user.login),
              _Info('Pseudonim', user.nickname),
              _Info('Imię i nazwisko', _fullNameValue(user)),
              _Info('Jednostka', user.unitName),
              _Info('Typ służby', user.unitType.label),
              _Info('Powiat', user.county),
              _Info('Województwo', user.voivodeship),
              _Info('Telefon', user.phoneNumberOrDash),
              _Info('Rola', user.role.label),
              _Info('Status konta', user.accountStatus.label),
              _Info('Opis', user.description),
              _Info('Dołączył', DateTimeUtils.compactDate(user.joinedAt)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.lock_reset),
            title: const Text('Zmień hasło'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(RoutePaths.changePassword),
          ),
        ),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(label),
      subtitle: Text(_value(value)),
    );
  }
}

String _value(String value) {
  final text = value.trim();
  return text.isEmpty || text == '-' ? 'Brak danych' : text;
}

String _fullNameValue(AppUser user) {
  return user.hasFullName
      ? user.fullName
      : 'Brak imienia i nazwiska — wymagane uzupełnienie';
}

String _presenceLabel(AppUser user) {
  if (user.presenceStatus == PresenceStatus.manual &&
      user.customStatus.isNotEmpty) {
    return user.customStatus;
  }
  final base = user.presenceStatus.label;
  if (user.presenceStatus == PresenceStatus.offline && user.lastSeenAt != null) {
    return '$base (widziano ${DateTimeUtils.chatTime(user.lastSeenAt!)})';
  }
  return base;
}

void _showStatusSelector(BuildContext context, WidgetRef ref, AppUser user) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Wybierz status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (final status in PresenceStatus.values)
            if (status != PresenceStatus.unavailable &&
                status != PresenceStatus.manual)
              ListTile(
                leading: Icon(
                  Icons.circle,
                  color: _presenceColor(status),
                  size: 16,
                ),
                title: Text(status.label),
                trailing: user.presenceStatus == status
                    ? const Icon(Icons.check, color: AppColors.green)
                    : null,
                onTap: () {
                  ref
                      .read(usersRepositoryProvider)
                      .updatePresence(
                        user.uid,
                        status,
                        manual: true,
                        currentStatus: user.presenceStatus,
                        currentIsManual: user.isManualStatus,
                      );
                  Navigator.pop(context);
                },
              ),
          ListTile(
            leading: const Icon(Icons.edit_outlined, size: 18),
            title: const Text('Własny status...'),
            onTap: () {
              Navigator.pop(context);
              context.push(RoutePaths.editProfile);
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

Color _presenceColor(PresenceStatus status) {
  return switch (status) {
    PresenceStatus.online => AppColors.green,
    PresenceStatus.busy => AppColors.orange,
    PresenceStatus.invisible => Colors.grey,
    _ => Colors.grey.shade600,
  };
}
