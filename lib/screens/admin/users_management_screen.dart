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
  active('Aktywne'),
  pending('Oczekujące'),
  blocked('Zablokowane'),
  admins('Admini'),
  moderators('Moderatorzy');

  const _UserFilter(this.label);
  final String label;
}

class UsersManagementScreen extends ConsumerStatefulWidget {
  const UsersManagementScreen({super.key});

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
    final usersStream = ref
        .watch(usersRepositoryProvider)
        .watchUsers(limit: _limit);
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
        _UserFilter.active => user.accountStatus == AccountStatus.active,
        _UserFilter.pending => user.accountStatus == AccountStatus.pending,
        _UserFilter.blocked =>
          user.accountStatus == AccountStatus.banned ||
              user.accountStatus == AccountStatus.suspended,
        _UserFilter.admins => user.role == UserRole.admin,
        _UserFilter.moderators => user.role == UserRole.moderator,
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
      child: ExpansionTile(
        leading: UserAvatar(user: user, radius: 22),
        title: Text(user.publicName),
        subtitle: Text('${user.login} • ${user.nickname} • ${user.unitName}'),
        trailing: AccountStatusBadge(user.accountStatus),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                  checkbox('viewExtraChats', 'Widoczność wybranych czatów'),
                  checkbox('viewExtraUnits', 'Widoczność wybranych jednostek'),
                  checkbox('moderateChats', 'Moderowanie wybranych czatów'),
                  checkbox('muteUsers', 'Wyciszanie użytkowników'),
                  checkbox('recallMessages', 'Cofanie wiadomości'),
                  checkbox('approveAccounts', 'Akceptowanie kont'),
                  checkbox('accessLogs', 'Dostęp do logów'),
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
      ('Imię i nazwisko', user.fullName),
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
