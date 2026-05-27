import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarnobrzeg112/core/app_constants.dart';
import 'package:tarnobrzeg112/core/firestore_collections.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';
import 'package:tarnobrzeg112/providers/service_mode_provider.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
import 'package:tarnobrzeg112/themes/app_colors.dart';
import 'package:tarnobrzeg112/utils/error_utils.dart';
import 'package:tarnobrzeg112/utils/text_utils.dart';
import 'package:tarnobrzeg112/widgets/app_scaffold.dart';
import 'package:tarnobrzeg112/widgets/empty_state.dart';
import 'package:tarnobrzeg112/widgets/loading_shimmer.dart';
import 'package:uuid/uuid.dart';

class ServiceModeScreen extends ConsumerStatefulWidget {
  const ServiceModeScreen({super.key});

  @override
  ConsumerState<ServiceModeScreen> createState() => _ServiceModeScreenState();
}

class _ServiceModeScreenState extends ConsumerState<ServiceModeScreen> {
  static const _duration = Duration(hours: 3);
  static const _envServiceCode = String.fromEnvironment('TBG112_SERVICE_CODE');
  static const _fallbackServiceCode = 'Tarnobrzeg112@2026';

  final _code = TextEditingController();
  final _uuid = const Uuid();
  Timer? _timer;
  bool _unlocking = false;
  String? _error;
  DateTime? _expiresAt;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreSession());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentAppUserProvider).asData?.value;
    final allowed =
        user?.isAdmin == true && user?.login == AppConstants.superAdminLogin;
    return AppScaffold(
      title: 'Serwis / Podgląd techniczny',
      showBackButton: true,
      fallbackRoute: RoutePaths.adminPanel,
      body: !allowed
          ? const EmptyState(
              icon: Icons.lock_outline,
              title: 'Brak dostępu',
              message: 'Tryb serwisowy jest dostępny tylko dla badura_admin.',
            )
          : _content(),
    );
  }

  Widget _content() {
    if (isServiceModeActive(_expiresAt)) {
      return _activeContent();
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wpisz kod serwisowy',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _code,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Kod serwisowy',
                    prefixIcon: Icon(Icons.key_outlined),
                  ),
                  onSubmitted: (_) => _unlock(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: AppColors.red)),
                ],
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _unlocking ? null : _unlock,
                  icon: _unlocking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_open_outlined),
                  label: const Text('Odblokuj podgląd'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _activeContent() {
    final remaining = _expiresAt!.difference(DateTime.now());
    final unitNames = ref.watch(activeUnitNamesProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 520;
                final status = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.visibility_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Niewidzialny podgląd aktywny',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pozostały czas: ${_formatDuration(remaining)}',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final button = OutlinedButton(
                  onPressed: () => _disable(manual: true),
                  child: const Text(
                    'Wyłącz tryb serwisowy',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [status, const SizedBox(height: 12), button],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: status),
                    const SizedBox(width: 12),
                    Flexible(child: button),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        unitNames.when(
          loading: () => const LoadingShimmer(
            timeoutTitle: 'Brak czatów jednostek',
            timeoutMessage: 'Nie znaleziono jednostek do podglądu.',
          ),
          error: (error, _) => EmptyState(
            icon: Icons.cloud_off,
            title: 'Nie można pobrać czatów',
            message: ErrorUtils.readable(error),
            actionLabel: 'Odśwież',
            onAction: () => ref.invalidate(activeUnitNamesProvider),
          ),
          data: (names) {
            final visible = names.toList()..sort();
            if (visible.isEmpty) {
              return const EmptyState(
                icon: Icons.apartment_outlined,
                title: 'Brak czatów jednostek',
                message: 'Lista pojawi się po zaakceptowaniu użytkowników.',
              );
            }
            return Column(
              children: [
                for (final name in visible)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.apartment_outlined),
                      title: Text(name),
                      subtitle: const Text(
                        'Podgląd tylko do odczytu. Bez pisania, reakcji i odczytań.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openUnitChat(name),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _restoreSession() async {
    final user = ref.read(currentAppUserProvider).asData?.value;
    if (user == null) return;
    final restored = kIsWeb
        ? await _restoreWebSession(user.uid)
        : await _restoreLocalSession(user.uid);
    if (!mounted) return;
    if (isServiceModeActive(restored)) {
      setState(() => _expiresAt = restored);
      ref.read(serviceModeExpiresAtProvider.notifier).state = restored;
    } else if (restored != null) {
      await _disable(manual: false);
    }
  }

  Future<void> _unlock() async {
    final user = ref.read(currentAppUserProvider).asData?.value;
    if (user == null) return;
    setState(() {
      _unlocking = true;
      _error = null;
    });
    try {
      final configuredCode = await _configuredServiceCode();
      if (configuredCode.trim().isEmpty) {
        throw StateError('Kod serwisowy nie jest skonfigurowany.');
      }
      if (_code.text.trim() != configuredCode.trim()) {
        throw StateError('Nieprawidłowy kod serwisowy.');
      }
      final expiresAt = DateTime.now().add(_duration);
      if (!kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
          _prefsKey(user.uid),
          expiresAt.millisecondsSinceEpoch,
        );
      }
      await _writeServiceSession(user.uid, expiresAt, active: true);
      await _log('service_mode_started', {
        'expiresAt': Timestamp.fromDate(expiresAt),
      });
      if (!mounted) return;
      setState(() => _expiresAt = expiresAt);
      ref.read(serviceModeExpiresAtProvider.notifier).state = expiresAt;
      _code.clear();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = ErrorUtils.readable(error));
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  Future<String> _configuredServiceCode() async {
    if (_envServiceCode.trim().isNotEmpty) return _envServiceCode;
    final firestore = ref.read(firestoreProvider);
    final doc = await firestore
        .collection(FirestoreCollections.appSettings)
        .doc('service_mode')
        .get();
    final data = doc.data() ?? const <String, Object?>{};
    final configured = (data['code'] ?? data['serviceCode'] ?? '').toString();
    return configured.trim().isEmpty ? _fallbackServiceCode : configured;
  }

  Future<void> _openUnitChat(String unitName) async {
    await _log('service_mode_open_chat', {'chatName': unitName});
    if (!mounted) return;
    context.push(
      '${RoutePaths.unitChat(TextUtils.normalizeId(unitName))}?service=1',
    );
  }

  Future<void> _disable({required bool manual}) async {
    final user = ref.read(currentAppUserProvider).asData?.value;
    if (user == null) return;
    final endedAt = DateTime.now();
    if (!kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey(user.uid));
    }
    await _writeServiceSession(user.uid, endedAt, active: false);
    await _log('service_mode_stopped', {
      'endedAt': Timestamp.fromDate(endedAt),
      'endReason': manual ? 'manual' : 'automatic',
    });
    if (!mounted) return;
    setState(() => _expiresAt = null);
    ref.read(serviceModeExpiresAtProvider.notifier).state = null;
  }

  Future<DateTime?> _restoreLocalSession(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_prefsKey(uid));
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<DateTime?> _restoreWebSession(String uid) async {
    final doc = await ref
        .read(firestoreProvider)
        .collection('service_sessions')
        .doc(uid)
        .get();
    final data = doc.data();
    if (data == null || data['active'] != true) return null;
    final expiresAt = data['expiresAt'];
    if (expiresAt is Timestamp) return expiresAt.toDate();
    return null;
  }

  Future<void> _writeServiceSession(
    String uid,
    DateTime expiresAt, {
    required bool active,
  }) {
    return ref
        .read(firestoreProvider)
        .collection('service_sessions')
        .doc(uid)
        .set({
          'uid': uid,
          'active': active,
          'expiresAt': Timestamp.fromDate(expiresAt),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> _log(String action, Map<String, Object?> extra) async {
    final user = ref.read(currentAppUserProvider).asData?.value;
    if (user == null) return;
    await ref
        .read(firestoreProvider)
        .collection(FirestoreCollections.moderationLogs)
        .doc(_uuid.v4())
        .set({
          'action': action,
          'performedBy': user.uid,
          'performedByLogin': user.login,
          'createdAt': FieldValue.serverTimestamp(),
          'device': 'flutter',
          ...extra,
        });
  }

  void _tick() {
    final expiresAt = _expiresAt;
    if (expiresAt == null) return;
    if (!isServiceModeActive(expiresAt)) {
      unawaited(_disable(manual: false));
      return;
    }
    if (mounted) setState(() {});
  }

  String _prefsKey(String uid) => 'serviceMode.expiresAt.$uid';

  String _formatDuration(Duration value) {
    final safe = value.isNegative ? Duration.zero : value;
    final hours = safe.inHours.toString().padLeft(2, '0');
    final minutes = safe.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}
