import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tarnobrzeg112/admin/admin_actions.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/core/locations.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';
import 'package:tarnobrzeg112/themes/app_colors.dart';
import 'package:tarnobrzeg112/utils/date_time_utils.dart';
import 'package:tarnobrzeg112/utils/error_utils.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/empty_state.dart';
import 'package:tarnobrzeg112/widgets/loading_shimmer.dart';
import 'package:tarnobrzeg112/widgets/status_chips.dart';
import 'package:tarnobrzeg112/widgets/user_avatar.dart';

enum _UserFilter {
  all('Wszyscy'),
  osp('OSP'),
  informator('Informator'),
  active('Aktywne'),
  pending('Oczekujące'),
  blocked('Zablokowane'),
  admins('Administrator'),
  moderators('Moderator'),
  muted('Wyciszeni');

  const _UserFilter(this.label);
  final String label;
}

class UsersManagementScreen extends ConsumerStatefulWidget {
  const UsersManagementScreen({this.initialFilter, super.key});

  final String? initialFilter;

  @override
  ConsumerState<UsersManagementScreen> createState() =>
      _UsersManagementScreenState();
}

class _UsersManagementScreenState extends ConsumerState<UsersManagementScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  var _filter = _UserFilter.all;
  String? _unitFilter;
  int _limit = 50;

  @override
  void initState() {
    super.initState();
    _filter = _filterFromWire(widget.initialFilter);
    _scrollController.addListener(_loadMoreIfNeeded);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount =
        ref.watch(pendingUsersProvider).asData?.value.length ?? 0;
    final stats = ref.watch(userStatsProvider).asData?.value;
    final repository = ref.watch(usersRepositoryProvider);
    final usersStream = _filter == _UserFilter.pending
        ? repository.watchPendingUsers(limit: _limit)
        : repository.watchUsers(limit: _limit);
    return AppScaffold(
      title: 'Użytkownicy',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Chip(
            avatar: const Icon(Icons.person_add_alt, size: 18),
            label: Text('Nowe konta: $pendingCount'),
          ),
        ),
      ],
      body: StreamBuilder<List<AppUser>>(
        stream: usersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return LoadingShimmer(
              timeoutTitle: 'Brak użytkowników',
              timeoutMessage: 'Lista użytkowników nie załadowała się.',
              onRefresh: () => setState(() {}),
            );
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.cloud_off,
              title: 'Nie można pobrać użytkowników',
              message: ErrorUtils.readable(snapshot.error!),
              actionLabel: 'Odśwież',
              onAction: () => setState(() {}),
            );
          }
          final loaded = snapshot.data ?? const <AppUser>[];
          final units = _unitNames(loaded);
          final filtered = _applyFilters(loaded);
          return Column(
            children: [
              _UsersStatsBar(stats: stats, pendingCount: pendingCount),
              _FiltersBar(
                filter: _filter,
                unitFilter: _unitFilter,
                units: units,
                searchController: _searchController,
                onFilterChanged: (value) => setState(() => _filter = value),
                onUnitChanged: (value) => setState(() => _unitFilter = value),
                onSearchChanged: (_) => setState(() {}),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.people_outline,
                        title: 'Brak użytkowników',
                        message: loaded.isEmpty
                            ? 'Nowe rejestracje pojawią się tutaj.'
                            : 'Zmień filtr albo wpisz inną frazę.',
                        actionLabel: 'Odśwież',
                        onAction: () => setState(() {}),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: filtered.length + 1,
                        itemBuilder: (context, index) {
                          if (index == filtered.length) {
                            return _LoadMoreFooter(
                              visible: loaded.length >= _limit,
                              onPressed: () => setState(() => _limit += 50),
                            );
                          }
                          return _UserCard(user: filtered[index]);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<AppUser> _applyFilters(List<AppUser> users) {
    final query = _searchController.text.trim().toLowerCase();
    return users.where((user) {
      final matchesFilter = switch (_filter) {
        _UserFilter.all => true,
        _UserFilter.osp => user.unitType == UnitType.osp,
        _UserFilter.informator => user.unitType == UnitType.informator,
        _UserFilter.active => user.accountStatus == AccountStatus.active,
        _UserFilter.pending => user.accountStatus == AccountStatus.pending,
        _UserFilter.blocked =>
          user.accountStatus == AccountStatus.banned ||
              user.accountStatus == AccountStatus.suspended,
        _UserFilter.admins => user.role == UserRole.admin,
        _UserFilter.moderators => user.role == UserRole.moderator,
        _UserFilter.muted => user.isMuted,
      };
      final matchesUnit =
          _unitFilter == null ||
          _unitFilter!.isEmpty ||
          user.unitName == _unitFilter;
      final haystack = [
        user.fullName,
        user.login,
        user.nickname,
        user.unitName,
        user.unitType.label,
        user.county,
      ].join(' ').toLowerCase();
      final matchesSearch = query.isEmpty || haystack.contains(query);
      return matchesFilter && matchesUnit && matchesSearch;
    }).toList();
  }

  List<String> _unitNames(List<AppUser> users) {
    final names =
        users
            .map((user) => user.unitName.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return names;
  }

  void _loadMoreIfNeeded() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (_limit < 1000 && position.pixels > position.maxScrollExtent - 600) {
      setState(() => _limit += 50);
    }
  }

  _UserFilter _filterFromWire(String? value) {
    return switch (value) {
      'osp' => _UserFilter.osp,
      'informator' => _UserFilter.informator,
      'active' => _UserFilter.active,
      'pending' => _UserFilter.pending,
      'blocked' => _UserFilter.blocked,
      'admins' => _UserFilter.admins,
      'moderators' => _UserFilter.moderators,
      'muted' => _UserFilter.muted,
      _ => _UserFilter.all,
    };
  }
}

class _UsersStatsBar extends StatelessWidget {
  const _UsersStatsBar({required this.stats, required this.pendingCount});

  final UserStats? stats;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Wszyscy użytkownicy', stats?.total ?? 0, Icons.groups_outlined),
      ('Do zatwierdzenia', stats?.pending ?? pendingCount, Icons.hourglass_top),
      ('Aktywni', stats?.active ?? 0, Icons.verified_outlined),
      ('Zablokowani', stats?.blocked ?? 0, Icons.block),
      ('Wyciszeni', stats?.muted ?? 0, Icons.volume_off_outlined),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: Icon(item.$3, size: 18),
                label: Text('${item.$1}: ${item.$2}'),
              ),
            ),
        ],
      ),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.filter,
    required this.unitFilter,
    required this.units,
    required this.searchController,
    required this.onFilterChanged,
    required this.onUnitChanged,
    required this.onSearchChanged,
  });

  final _UserFilter filter;
  final String? unitFilter;
  final List<String> units;
  final TextEditingController searchController;
  final ValueChanged<_UserFilter> onFilterChanged;
  final ValueChanged<String?> onUnitChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              labelText: 'Szukaj użytkownika',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: unitFilter ?? '',
            decoration: const InputDecoration(
              labelText: 'Jednostka',
              prefixIcon: Icon(Icons.apartment_outlined),
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('Wszystkie')),
              for (final unit in units)
                DropdownMenuItem(value: unit, child: Text(unit)),
            ],
            onChanged: onUnitChanged,
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final item in _UserFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: filter == item,
                      label: Text(item.label),
                      onSelected: (_) => onFilterChanged(item),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.visible, required this.onPressed});

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox(height: 24);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.expand_more),
          label: const Text('Doładuj kolejnych użytkowników'),
        ),
      ),
    );
  }
}

class _UserCard extends ConsumerWidget {
  const _UserCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        visualDensity: VisualDensity.compact,
        leading: UserAvatar(user: user, radius: 22),
        title: Text(
          user.nickname.trim().isEmpty ? user.displayName : user.nickname,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          _userSubtitle(user),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: AccountStatusBadge(user.accountStatus),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              RoleBadge(user.role),
              UnitBadge(type: user.unitType, name: user.unitName),
              if (user.isMuted) const MutedBadge(),
              if (user.isTrustedAdminCandidate)
                const Chip(
                  avatar: Icon(Icons.verified_user, size: 16),
                  label: Text('Zaufany admin'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoGrid(user: user),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: () => AdminActions.changeStatus(
                  ref,
                  context,
                  user,
                  AccountStatus.active,
                ),
                child: Text(
                  user.accountStatus == AccountStatus.banned ||
                          user.accountStatus == AccountStatus.suspended
                      ? 'Odblokuj'
                      : 'Akceptuj',
                ),
              ),
              OutlinedButton(
                onPressed: () => AdminActions.changeStatus(
                  ref,
                  context,
                  user,
                  AccountStatus.rejected,
                ),
                child: const Text('Odrzuć'),
              ),
              OutlinedButton(
                onPressed: () => AdminActions.changeStatus(
                  ref,
                  context,
                  user,
                  AccountStatus.banned,
                ),
                child: const Text('Zablokuj'),
              ),
              OutlinedButton(
                onPressed: () => AdminActions.mute(ref, context, user),
                child: const Text('Wycisz 24h'),
              ),
              OutlinedButton.icon(
                onPressed: () => AdminActions.resetPassword(ref, context, user),
                icon: const Icon(Icons.password_outlined),
                label: const Text('Resetuj hasło'),
              ),
              OutlinedButton.icon(
                onPressed: () => AdminActions.deleteUser(ref, context, user),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Usuń użytkownika'),
              ),
              OutlinedButton.icon(
                onPressed: () => _showFullNameDialog(context, ref),
                icon: const Icon(Icons.badge_outlined),
                label: const Text('Zmień imię i nazwisko'),
              ),
              if (user.isMuted)
                OutlinedButton(
                  onPressed: () => AdminActions.unmute(ref, context, user),
                  child: const Text('Odblokuj pisanie'),
                ),
              OutlinedButton(
                onPressed: () =>
                    AdminActions.changeRole(ref, context, user, UserRole.user),
                child: const Text('User'),
              ),
              if (user.role == UserRole.moderator)
                OutlinedButton(
                  onPressed: () =>
                      _showModeratorPermissionsDialog(context, ref),
                  child: const Text('Uprawnienia moderatora'),
                ),
              OutlinedButton(
                onPressed: () => AdminActions.changeRole(
                  ref,
                  context,
                  user,
                  UserRole.moderator,
                ),
                child: const Text('Moderator'),
              ),
              OutlinedButton(
                onPressed: () =>
                    AdminActions.changeRole(ref, context, user, UserRole.admin),
                child: const Text('Admin'),
              ),
              OutlinedButton(
                onPressed: () => _showServiceDialog(context, ref),
                child: const Text('Zmień dane służby'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _userSubtitle(AppUser user) {
    final unit = user.unitName.trim();
    final type = user.unitType.label;
    if (unit.isEmpty ||
        user.unitType == UnitType.informator ||
        user.unitType == UnitType.media) {
      return type;
    }
    return '$type · $unit';
  }

  Future<void> _showFullNameDialog(BuildContext context, WidgetRef ref) async {
    final actor = ref.read(currentAppUserProvider).asData?.value;
    if (actor == null) return;
    final fullName = TextEditingController(text: user.fullName);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Imię i nazwisko'),
        content: TextField(
          controller: fullName,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Imię i nazwisko',
            helperText: 'Wymagane co najmniej dwa wyrazy',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () async {
              final parts = fullName.text
                  .trim()
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .split(' ')
                  .where((part) => part.isNotEmpty)
                  .toList();
              if (parts.length < 2) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Wpisz imię i nazwisko.')),
                );
                return;
              }
              await ref
                  .read(moderationRepositoryProvider)
                  .updateUserFullName(
                    actor: actor,
                    target: user,
                    firstName: parts.first,
                    lastName: parts.skip(1).join(' '),
                  );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
    fullName.dispose();
  }

  Future<void> _showModeratorPermissionsDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final actor = ref.read(currentAppUserProvider).asData?.value;
    if (actor == null) return;
    final permissions = Map<String, bool>.from(user.moderatorPermissions);
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          Widget checkbox(String key, String label) {
            return CheckboxListTile(
              value: permissions[key] == true,
              title: Text(label),
              onChanged: (value) {
                setState(() => permissions[key] = value == true);
              },
            );
          }

          return AlertDialog(
            title: const Text('Uprawnienia moderatora'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Dostęp do kanałów',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  checkbox('channelPsp', 'PSP'),
                  checkbox('channelPolicja', 'Policja'),
                  checkbox('channelMedycy', 'Medycy'),
                  checkbox('channelMedia', 'Media'),
                  const Divider(),
                  checkbox('viewExtraChats', 'Widoczność wybranych czatów'),
                  checkbox('viewExtraUnits', 'Widoczność wybranych jednostek'),
                  checkbox('manageUsers', 'Zarządzanie użytkownikami'),
                  checkbox(
                    'manageChatMembers',
                    'Dodawanie i usuwanie członków czatów',
                  ),
                  checkbox('moderateChats', 'Moderowanie wybranych czatów'),
                  checkbox('muteUsers', 'Wyciszanie użytkowników'),
                  checkbox('unmuteUsers', 'Cofanie wyciszeń'),
                  checkbox('manageEvents', 'Wydarzenia'),
                  checkbox('manageAnnouncements', 'Komunikaty'),
                  checkbox('recallMessages', 'Cofanie wiadomości'),
                  checkbox('deleteMessages', 'Usuwanie wiadomości'),
                  checkbox('editMessages', 'Edycja wiadomości'),
                  checkbox('approveAccounts', 'Akceptowanie kont'),
                  checkbox('accessLogs', 'Dostęp do logów'),
                  checkbox('reports', 'Raporty'),
                  checkbox(
                    'allowScreenshots',
                    'Zezwól moderatorowi wykonywać zrzuty',
                  ),
                  checkbox('serviceUnitsAccess', 'Dostęp do jednostek'),
                  checkbox('extraFeatures', 'Dodatkowe funkcje'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Anuluj'),
              ),
              FilledButton(
                onPressed: () async {
                  await ref
                      .read(moderationRepositoryProvider)
                      .updateModeratorPermissions(
                        actor: actor,
                        target: user,
                        permissions: permissions,
                      );
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Zapisz'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showServiceDialog(BuildContext context, WidgetRef ref) async {
    var voivodeship = user.voivodeship;
    var county = user.county;
    var unitType = user.unitType;
    final unitName = TextEditingController(text: user.unitName);
    final actor = ref.read(currentAppUserProvider).asData?.value;
    if (actor == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final counties = AppLocations.countiesFor(voivodeship);
            if (!counties.contains(county)) county = counties.first;
            return AlertDialog(
              title: const Text('Dane służby'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: voivodeship,
                      decoration: const InputDecoration(
                        labelText: 'Województwo',
                      ),
                      items: AppLocations.voivodeships
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          voivodeship = value;
                          county = AppLocations.countiesFor(value).first;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: county,
                      decoration: const InputDecoration(labelText: 'Powiat'),
                      items: counties
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => county = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<UnitType>(
                      initialValue: unitType,
                      decoration: const InputDecoration(
                        labelText: 'Typ służby',
                      ),
                      items: UnitType.values
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => unitType = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: unitName,
                      decoration: const InputDecoration(
                        labelText: 'Jednostka / funkcja',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Anuluj'),
                ),
                FilledButton(
                  onPressed: () async {
                    await ref
                        .read(moderationRepositoryProvider)
                        .updateUserServiceData(
                          actor: actor,
                          target: user,
                          voivodeship: voivodeship,
                          county: county,
                          unitType: unitType,
                          unitName: unitName.text.trim(),
                        );
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Zapisz'),
                ),
              ],
            );
          },
        );
      },
    );
    unitName.dispose();
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Login', user.login),
      ('Imię i nazwisko', _fullNameValue(user)),
      ('Pseudonim', user.nickname),
      ('Telefon', user.phoneNumberOrDash),
      ('Województwo', user.voivodeship),
      ('Powiat', user.county),
      ('Typ służby', user.unitType.label),
      ('Jednostka / funkcja', user.unitName),
      ('Typ wpisany przy rejestracji', user.requestedUnitType),
      ('Jednostka wpisana przy rejestracji', user.requestedUnitName),
      ('Uwagi', user.adminNotes),
      ('Wyciszenie', user.isMuted ? user.mutedReason : ''),
      ('Rejestracja', DateTimeUtils.compactDate(user.joinedAt)),
    ];
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 132,
                  child: Text(
                    row.$1,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ),
                Expanded(
                  child: Text(row.$2.trim().isEmpty ? 'Brak danych' : row.$2),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String _fullNameValue(AppUser user) {
  return user.hasFullName
      ? user.fullName
      : 'Brak imienia i nazwiska — wymagane uzupełnienie';
}
