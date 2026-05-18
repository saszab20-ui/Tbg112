import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
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
          onPressed: () => context.go(RoutePaths.editProfile),
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

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
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
                _value(user.nickname),
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
              _Info('Login', user.login),
              _Info('Pseudonim', user.nickname),
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
            onTap: () => context.go(RoutePaths.changePassword),
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
