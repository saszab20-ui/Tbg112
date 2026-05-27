import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:tarnobrzeg112/models/event_model.dart';
import 'package:tarnobrzeg112/models/notification_model.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';
import 'package:tarnobrzeg112/themes/app_colors.dart';
import 'package:tarnobrzeg112/services/local_preferences.dart';
import 'package:tarnobrzeg112/utils/date_time_utils.dart';
import 'package:tarnobrzeg112/utils/error_utils.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/empty_state.dart';
import 'package:tarnobrzeg112/widgets/loading_shimmer.dart';
import 'package:tarnobrzeg112/widgets/user_avatar.dart';
import 'package:url_launcher/url_launcher.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAppUserProvider).asData?.value;
    if (user == null) {
      return const AppScaffold(
        title: 'Info',
        currentIndex: 3,
        body: EmptyState(
          icon: Icons.notifications_off_outlined,
          title: 'Brak sesji',
          message: 'Zaloguj się ponownie.',
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: AppScaffold(
        title: 'Info',
        currentIndex: 3,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => user.isAdmin
              ? _showCreateSheet(context, ref)
              : _showEventDialog(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Dodaj'),
        ),
        body: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.event_outlined), text: 'Wydarzenia'),
                Tab(icon: Icon(Icons.campaign_outlined), text: 'Komunikaty'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _EventsList(currentUserId: user.uid),
                  _NotificationsList(currentUser: user),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateSheet(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<_InfoCreateAction>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.panel,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('Wydarzenie'),
              subtitle: const Text('Dodaj wydarzenie widoczne w zakładce Info'),
              onTap: () => Navigator.pop(context, _InfoCreateAction.event),
            ),
            ListTile(
              leading: const Icon(Icons.campaign_outlined),
              title: const Text('Komunikat'),
              subtitle: const Text('Przypięta informacja dla użytkowników'),
              onTap: () => Navigator.pop(context, _InfoCreateAction.broadcast),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    if (action == _InfoCreateAction.event) {
      await _showEventDialog(context, ref);
    } else {
      await _showBroadcastDialog(context, ref);
    }
  }

  Future<void> _showBroadcastDialog(BuildContext context, WidgetRef ref) async {
    final actor = ref.read(currentAppUserProvider).asData?.value;
    if (actor == null) return;
    final title = TextEditingController();
    final body = TextEditingController();
    final prefs = await loadLocalPreferences();
    title.text = prefs.getString('info_broadcast_draft.title') ?? '';
    body.text = prefs.getString('info_broadcast_draft.body') ?? '';
    void saveDraft() {
      unawaited(prefs.setString('info_broadcast_draft.title', title.text));
      unawaited(prefs.setString('info_broadcast_draft.body', body.text));
    }

    Future<void> clearDraft() async {
      await prefs.remove('info_broadcast_draft.title');
      await prefs.remove('info_broadcast_draft.body');
    }

    title.addListener(saveDraft);
    body.addListener(saveDraft);
    var saving = false;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Przypięty komunikat'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Tytuł'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: body,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Treść'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                unawaited(clearDraft());
                Navigator.pop(context);
              },
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      setDialogState(() => saving = true);
                      try {
                        await ref
                            .read(notificationsRepositoryProvider)
                            .createBroadcast(
                              actor: actor,
                              title: title.text,
                              body: body.text,
                            );
                        await clearDraft();
                        if (context.mounted) Navigator.pop(context);
                      } on Object catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(ErrorUtils.readable(error))),
                          );
                        }
                      } finally {
                        if (context.mounted) {
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Dodaj'),
            ),
          ],
        ),
      ),
    );
    title.removeListener(saveDraft);
    body.removeListener(saveDraft);
    title.dispose();
    body.dispose();
  }

  Future<void> _showEventDialog(
    BuildContext context,
    WidgetRef ref, {
    EventModel? event,
  }) async {
    final user = ref.read(currentAppUserProvider).asData?.value;
    if (user == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _CreateEventDialog(userId: user.uid, event: event),
    );
  }
}

enum _InfoCreateAction { event, broadcast }

class _NotificationsList extends ConsumerWidget {
  const _NotificationsList({required this.currentUser});

  final AppUser currentUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref
        .watch(notificationsRepositoryProvider)
        .watchForUser(currentUser.uid);
    return StreamBuilder<List<NotificationModel>>(
      stream: notifications,
      initialData: const <NotificationModel>[],
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.cloud_off,
            title: 'Nie można pobrać komunikatów',
            message: ErrorUtils.readable(snapshot.error!),
            actionLabel: 'Odśwież',
            onAction: () => ref.invalidate(notificationsRepositoryProvider),
          );
        }
        final immediateItems = snapshot.data;
        if (immediateItems != null && immediateItems.isEmpty) {
          return const EmptyState(
            icon: Icons.notifications_none,
            title: 'Brak komunikatów',
            message: 'Nowe informacje pojawi? si? w tym miejscu.',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return LoadingShimmer(
            timeoutTitle: 'Brak komunikatów',
            timeoutMessage: 'Nie ma jeszcze komunikatów do wyświetlenia.',
            onRefresh: () => ref.invalidate(notificationsRepositoryProvider),
          );
        }
        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.cloud_off,
            title: 'Nie można pobrać komunikatów',
            message: ErrorUtils.readable(snapshot.error!),
            actionLabel: 'Odśwież',
            onAction: () => ref.invalidate(notificationsRepositoryProvider),
          );
        }
        final items = snapshot.data ?? const <NotificationModel>[];
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.notifications_none,
            title: 'Brak komunikatów',
            message: 'Nowe informacje pojawi? si? w tym miejscu.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final pinned = item.data['pinned'] == 'true';
            final canManage =
                currentUser.isAdmin ||
                item.data['createdBy'] == currentUser.uid;
            return Card(
              child: ListTile(
                leading: Icon(
                  pinned
                      ? Icons.push_pin
                      : item.read
                      ? Icons.done
                      : Icons.circle,
                ),
                title: Text(item.title),
                subtitle: Text(item.body),
                trailing: canManage
                    ? PopupMenuButton<_AnnouncementAction>(
                        onSelected: (action) => _handleAnnouncementAction(
                          context,
                          ref,
                          item,
                          action,
                        ),
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: _AnnouncementAction.edit,
                            child: Text('Edytuj'),
                          ),
                          PopupMenuItem(
                            value: _AnnouncementAction.delete,
                            child: Text('Usuń'),
                          ),
                        ],
                      )
                    : Text(item.type.label),
                onTap: item.recipientId == 'all'
                    ? null
                    : () => ref
                          .read(notificationsRepositoryProvider)
                          .markRead(item.id),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleAnnouncementAction(
    BuildContext context,
    WidgetRef ref,
    NotificationModel item,
    _AnnouncementAction action,
  ) async {
    switch (action) {
      case _AnnouncementAction.edit:
        await _editAnnouncement(context, ref, item);
        break;
      case _AnnouncementAction.delete:
        await _deleteAnnouncement(context, ref, item);
        break;
    }
  }

  Future<void> _editAnnouncement(
    BuildContext context,
    WidgetRef ref,
    NotificationModel item,
  ) async {
    final title = TextEditingController(text: item.title);
    final body = TextEditingController(text: item.body);
    try {
      final save = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Edytuj komunikat'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Tytuł'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: body,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Treść'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Zapisz'),
            ),
          ],
        ),
      );
      if (save != true) return;
      await ref
          .read(notificationsRepositoryProvider)
          .updateBroadcast(
            notification: item,
            actor: currentUser,
            title: title.text,
            body: body.text,
          );
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ErrorUtils.readable(error))));
    } finally {
      title.dispose();
      body.dispose();
    }
  }

  Future<void> _deleteAnnouncement(
    BuildContext context,
    WidgetRef ref,
    NotificationModel item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usunąć komunikat?'),
        content: const Text('Czy na pewno usunąć ten komunikat?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(notificationsRepositoryProvider)
          .deleteBroadcast(notification: item, actor: currentUser);
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ErrorUtils.readable(error))));
    }
  }
}

enum _AnnouncementAction { edit, delete }

class _EventsList extends ConsumerStatefulWidget {
  const _EventsList({required this.currentUserId});

  final String currentUserId;

  @override
  ConsumerState<_EventsList> createState() => _EventsListState();
}

class _EventsListState extends ConsumerState<_EventsList> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Refresh every minute to update expiration status
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentAppUserProvider).asData?.value;
    final stream = ref.watch(eventsRepositoryProvider).watchEvents();
    final users = ref.watch(activeUsersProvider).asData?.value ?? const [];
    return StreamBuilder<List<EventModel>>(
      stream: stream,
      initialData: const <EventModel>[],
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.cloud_off,
            title: 'Nie można pobrać wydarzeń',
            message: ErrorUtils.readable(snapshot.error!),
            actionLabel: 'Odśwież',
            onAction: () => ref.invalidate(eventsRepositoryProvider),
          );
        }
        final rawItems = snapshot.data ?? const <EventModel>[];
        final now = DateTime.now();
        final cutoff = now.subtract(const Duration(hours: 4));
        final displayItems = rawItems.where((event) {
          if (user?.isModerator == true) return true;
          return event.dateTime.isAfter(cutoff);
        }).toList();

        if (displayItems.isNotEmpty) {
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            itemCount: displayItems.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _EventCard(
              event: displayItems[index],
              currentUserId: widget.currentUserId,
              users: users,
            ),
          );
        }
        final immediateItems = snapshot.data;
        if (immediateItems != null && immediateItems.isEmpty) {
          return const EmptyState(
            icon: Icons.event_busy_outlined,
            title: 'Brak wydarzeń',
            message: 'Dodaj pierwsze wydarzenie dla społeczności.',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return LoadingShimmer(
            timeoutTitle: 'Brak wydarzeń',
            timeoutMessage: 'Nie dodano jeszcze żadnego wydarzenia.',
            onRefresh: () => ref.invalidate(eventsRepositoryProvider),
          );
        }
        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.cloud_off,
            title: 'Nie można pobrać wydarzeń',
            message: ErrorUtils.readable(snapshot.error!),
            actionLabel: 'Odśwież',
            onAction: () => ref.invalidate(eventsRepositoryProvider),
          );
        }
        if (displayItems.isEmpty) {
          return const EmptyState(
            icon: Icons.event_busy_outlined,
            title: 'Brak wydarzeń',
            message: 'Dodaj pierwsze wydarzenie dla społeczności.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          itemCount: displayItems.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _EventCard(
            event: displayItems[index],
            currentUserId: widget.currentUserId,
            users: users,
          ),
        );
      },
    );
  }
}

class _EventCard extends ConsumerWidget {
  const _EventCard({
    required this.event,
    required this.currentUserId,
    required this.users,
  });

  final EventModel event;
  final String currentUserId;
  final List<AppUser> users;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentAppUserProvider).asData?.value;
    final canManageEvent =
        currentUser != null &&
        (currentUser.isAdmin ||
            currentUser.moderatorCan('manageEvents') ||
            event.organizerId == currentUser.uid);
    final interested = event.interestedIds.contains(currentUserId);
    final attending = event.attendeeIds.contains(currentUserId);
    final attendeeUsers = users
        .where((user) => event.attendeeIds.contains(user.uid))
        .take(6)
        .toList();
    AppUser? creator;
    for (final user in users) {
      if (user.uid == event.organizerId) {
        creator = user;
        break;
      }
    }
    final creatorLabel = creator == null
        ? event.organizerName
        : '${creator.publicName} (${creator.role.label})';
    return Card(
      elevation: 8,
      margin: const EdgeInsets.only(bottom: 6),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (event.hasPoster)
            GestureDetector(
              onTap: () => _openPoster(context),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _PosterImage(event: event, fit: BoxFit.cover),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                _InfoLine(
                  icon: Icons.calendar_month_outlined,
                  text: DateTimeUtils.compactDate(event.dateTime),
                ),
                _InfoLine(
                  icon: Icons.schedule,
                  text:
                      '${event.dateTime.hour.toString().padLeft(2, '0')}:${event.dateTime.minute.toString().padLeft(2, '0')}',
                ),
                _InfoLine(icon: Icons.place_outlined, text: event.place),
                _InfoLine(
                  icon: Icons.person_outline,
                  text: 'Utworzył: $creatorLabel',
                ),
                if (event.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(event.description),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Uczestnicy: ${event.attendeeIds.length}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 10),
                    for (final user in attendeeUsers)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: UserAvatar(user: user, radius: 14),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      selected: interested,
                      label: Text(
                        'Zainteresowany (${event.interestedIds.length})',
                      ),
                      onSelected: currentUser == null
                          ? null
                          : (_) => _toggleInterested(context, ref, currentUser),
                    ),
                    FilterChip(
                      selected: attending,
                      label: Text('Wezmę udział (${event.attendeeIds.length})'),
                      onSelected: currentUser == null
                          ? null
                          : (_) => _toggleAttending(context, ref, currentUser),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _share(context),
                      icon: const Icon(Icons.ios_share_outlined),
                      label: const Text('Udostępnij'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openMaps(event.place),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Mapa'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openCalendar(event),
                      icon: const Icon(Icons.event_available_outlined),
                      label: const Text('Kalendarz'),
                    ),
                    if (canManageEvent) ...[
                      OutlinedButton.icon(
                        onPressed: () => _editEvent(context, ref),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edytuj'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _deleteEvent(context, ref),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Usuń'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    final text =
        '${event.name}\n${DateTimeUtils.compactDate(event.dateTime)}\n${event.place}\n${event.description}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Treść wydarzenia skopiowana.')),
    );
  }

  void _toggleInterested(BuildContext context, WidgetRef ref, AppUser user) {
    unawaited(
      ref
          .read(eventsRepositoryProvider)
          .toggleInterested(event: event, user: user)
          .catchError((Object error) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(ErrorUtils.readable(error))),
              );
            }
          }),
    );
  }

  void _toggleAttending(BuildContext context, WidgetRef ref, AppUser user) {
    unawaited(
      ref
          .read(eventsRepositoryProvider)
          .toggleAttending(event: event, user: user)
          .catchError((Object error) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(ErrorUtils.readable(error))),
              );
            }
          }),
    );
  }

  Future<void> _editEvent(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentAppUserProvider).asData?.value;
    if (user == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _CreateEventDialog(userId: user.uid, event: event),
    );
  }

  Future<void> _deleteEvent(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentAppUserProvider).asData?.value;
    if (user == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usunąć wydarzenie?'),
        content: const Text('Czy na pewno usunąć wydarzenie?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(eventsRepositoryProvider)
          .deleteEvent(event: event, actor: user);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Wydarzenie usunięte.')));
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ErrorUtils.readable(error))));
    }
  }

  Future<void> _openMaps(String place) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': place,
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openCalendar(EventModel event) async {
    final start = event.dateTime.toUtc();
    final end = start.add(const Duration(hours: 2));
    String stamp(DateTime value) {
      return value
          .toIso8601String()
          .replaceAll('-', '')
          .replaceAll(':', '')
          .split('.')
          .first;
    }

    final uri = Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': event.name,
      'dates': '${stamp(start)}Z/${stamp(end)}Z',
      'location': event.place,
      'details': event.description,
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openPoster(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Stack(
          children: [
            Positioned.fill(
              child: _PosterImage(event: event, fit: BoxFit.contain),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton.filledTonal(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateEventDialog extends ConsumerStatefulWidget {
  const _CreateEventDialog({required this.userId, this.event});

  final String userId;
  final EventModel? event;

  @override
  ConsumerState<_CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends ConsumerState<_CreateEventDialog> {
  static const _draftPrefix = 'info_event_draft';

  final _name = TextEditingController();
  final _place = TextEditingController();
  final _description = TextEditingController();
  final _picker = ImagePicker();
  DateTime _dateTime = DateTime.now().add(const Duration(days: 1));
  bool _notifyUsers = true;
  XFile? _posterFile;
  String _posterPath = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    if (event != null) {
      _name.text = event.name;
      _place.text = event.place;
      _description.text = event.description;
      _dateTime = event.dateTime;
      _notifyUsers = event.notifyUsers;
    }
    _name.addListener(_saveDraft);
    _place.addListener(_saveDraft);
    _description.addListener(_saveDraft);
    if (event == null) {
      unawaited(_restoreDraft());
    }
    unawaited(_recoverLostPoster());
  }

  @override
  void dispose() {
    _name.removeListener(_saveDraft);
    _place.removeListener(_saveDraft);
    _description.removeListener(_saveDraft);
    _name.dispose();
    _place.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.event == null ? 'Nowe wydarzenie' : 'Edytuj wydarzenie',
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nazwa'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(DateTimeUtils.compactDate(_dateTime)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule),
                      label: Text(
                        '${_dateTime.hour.toString().padLeft(2, '0')}:${_dateTime.minute.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _place,
                decoration: const InputDecoration(labelText: 'Miejsce'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _description,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Opis'),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _posterPreview(),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickPoster,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Plakat z telefonu'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _takePosterPhoto,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Plakat z aparatu'),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _notifyUsers,
                onChanged: (value) {
                  setState(() => _notifyUsers = value);
                  _saveDraft();
                },
                title: const Text('Powiadom użytkowników'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () {
                  unawaited(_clearDraft());
                  Navigator.pop(context);
                },
          child: const Text('Anuluj'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  widget.event == null ? 'Dodaj wydarzenie' : 'Zapisz zmiany',
                ),
        ),
      ],
    );
  }

  Widget _posterPreview() {
    if (_posterFile != null) {
      return FutureBuilder<Uint8List>(
        future: _posterFile!.readAsBytes(),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) return const ColoredBox(color: AppColors.panelAlt);
          return Image.memory(bytes, fit: BoxFit.cover);
        },
      );
    }
    final event = widget.event;
    if (event != null && event.hasPoster) {
      return _PosterImage(event: event, fit: BoxFit.cover);
    }
    return const ColoredBox(
      color: AppColors.panelAlt,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, size: 42, color: AppColors.muted),
            SizedBox(height: 8),
            Text('Dodaj plakat z telefonu albo aparatu'),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() {
      _dateTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _dateTime.hour,
        _dateTime.minute,
      );
    });
    _saveDraft();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (picked == null) return;
    setState(() {
      _dateTime = DateTime(
        _dateTime.year,
        _dateTime.month,
        _dateTime.day,
        picked.hour,
        picked.minute,
      );
    });
    _saveDraft();
  }

  Future<void> _pickPoster() async {
    await _pickPosterFrom(ImageSource.gallery);
  }

  Future<void> _takePosterPhoto() async {
    await _pickPosterFrom(ImageSource.camera);
  }

  Future<void> _pickPosterFrom(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 84,
        maxWidth: 1800,
        maxHeight: 1800,
      );
      if (!mounted || file == null) return;
      setState(() {
        _posterFile = file;
        _posterPath = file.path;
      });
      _saveDraft();
    } on Object catch (error) {
      debugPrint('EVENT POSTER PICK ERROR: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie udało się dodać plakatu.')),
      );
    }
  }

  Future<void> _restoreDraft() async {
    final prefs = await loadLocalPreferences();
    if (!mounted) return;
    final timestamp = prefs.getInt('$_draftPrefix.dateTime');
    final posterPath = prefs.getString('$_draftPrefix.posterPath') ?? '';
    setState(() {
      _name.text = prefs.getString('$_draftPrefix.name') ?? _name.text;
      _place.text = prefs.getString('$_draftPrefix.place') ?? _place.text;
      _description.text =
          prefs.getString('$_draftPrefix.description') ?? _description.text;
      if (timestamp != null) {
        _dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      _notifyUsers = prefs.getBool('$_draftPrefix.notifyUsers') ?? true;
      if (!kIsWeb && posterPath.isNotEmpty) {
        _posterPath = posterPath;
        _posterFile = XFile(posterPath);
      }
    });
  }

  Future<void> _recoverLostPoster() async {
    if (kIsWeb) return;
    try {
      final response = await _picker.retrieveLostData();
      if (!mounted || response.isEmpty || response.exception != null) return;
      final file = response.file ?? response.files?.firstOrNull;
      if (file == null || response.type == RetrieveType.video) return;
      setState(() {
        _posterFile = file;
        _posterPath = file.path;
      });
      _saveDraft();
    } on Object catch (error) {
      debugPrint('EVENT POSTER LOST DATA RECOVERY ERROR: $error');
    }
  }

  Future<void> _saveDraft() async {
    if (widget.event != null) return;
    final prefs = await loadLocalPreferences();
    await prefs.setString('$_draftPrefix.name', _name.text);
    await prefs.setString('$_draftPrefix.place', _place.text);
    await prefs.setString('$_draftPrefix.description', _description.text);
    await prefs.setInt(
      '$_draftPrefix.dateTime',
      _dateTime.millisecondsSinceEpoch,
    );
    await prefs.setBool('$_draftPrefix.notifyUsers', _notifyUsers);
    await prefs.setString('$_draftPrefix.posterPath', _posterPath);
  }

  Future<void> _clearDraft() async {
    final prefs = await loadLocalPreferences();
    for (final key in [
      '$_draftPrefix.name',
      '$_draftPrefix.place',
      '$_draftPrefix.description',
      '$_draftPrefix.dateTime',
      '$_draftPrefix.notifyUsers',
      '$_draftPrefix.posterPath',
    ]) {
      await prefs.remove(key);
    }
  }

  Future<void> _save() async {
    final user = ref.read(currentAppUserProvider).asData?.value;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final repository = ref.read(eventsRepositoryProvider);
      final event = widget.event;
      if (event == null) {
        await repository.createEvent(
          organizer: user,
          name: _name.text,
          dateTime: _dateTime,
          place: _place.text,
          description: _description.text,
          notifyUsers: _notifyUsers,
          posterFile: _posterFile,
          posterAsset: '',
        );
      } else {
        await repository.updateEvent(
          event: event,
          actor: user,
          name: _name.text,
          dateTime: _dateTime,
          place: _place.text,
          description: _description.text,
          notifyUsers: _notifyUsers,
          posterFile: _posterFile,
        );
      }
      await _clearDraft();
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ErrorUtils.readable(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _PosterImage extends StatelessWidget {
  const _PosterImage({required this.event, required this.fit});

  final EventModel event;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (event.isAssetPoster) {
      final assetPath = event.assetPosterPath;
      if (kIsWeb) {
        return Image.network(
          Uri.base.resolve('assets/$assetPath').toString(),
          fit: fit,
          errorBuilder: (_, _, _) => const ColoredBox(
            color: AppColors.panelAlt,
            child: Center(child: Icon(Icons.broken_image_outlined)),
          ),
        );
      }
      return Image.asset(
        assetPath,
        fit: fit,
        errorBuilder: (_, _, _) => const ColoredBox(
          color: AppColors.panelAlt,
          child: Center(child: Icon(Icons.broken_image_outlined)),
        ),
      );
    }
    return Image.network(
      event.posterUrl,
      fit: fit,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: AppColors.panelAlt,
        child: Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.orange),
          const SizedBox(width: 7),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
