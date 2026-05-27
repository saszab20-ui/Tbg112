import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tarnobrzeg112/core/app_constants.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:tarnobrzeg112/providers/auth_providers.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';
import 'package:tarnobrzeg112/providers/navigation_providers.dart';
import 'package:tarnobrzeg112/providers/settings_providers.dart';
import 'package:tarnobrzeg112/routes/app_router.dart';
import 'package:tarnobrzeg112/routes/route_paths.dart';
import 'package:tarnobrzeg112/services/privacy_service.dart';
import 'package:tarnobrzeg112/themes/app_theme.dart';

class Tarnobrzeg112App extends ConsumerStatefulWidget {
  const Tarnobrzeg112App({super.key});

  @override
  ConsumerState<Tarnobrzeg112App> createState() => _Tarnobrzeg112AppState();
}

class _Tarnobrzeg112AppState extends ConsumerState<Tarnobrzeg112App>
    with WidgetsBindingObserver {
  StreamSubscription<String>? _notificationRoutes;
  Timer? _presenceHeartbeat;
  DateTime? _lastPresenceWrite;
  String? _presenceUid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyPrivacyMode();
      _notificationRoutes ??= ref
          .read(notificationServiceProvider)
          .openedRoutes()
          .listen(_openNotificationRoute);
      _presenceHeartbeat = Timer.periodic(
        const Duration(minutes: 2),
        (_) => _markActive(force: true),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationRoutes?.cancel();
    _presenceHeartbeat?.cancel();
    _markOffline();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _markActive(force: true);
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _markOffline();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final currentProfile = ref.watch(currentAppUserProvider).asData?.value;
    ref.read(notificationServiceProvider).setCurrentUserId(currentProfile?.uid);
    ref.listen(currentAppUserProvider, (_, next) {
      final profile = next.asData?.value;
      final pendingRoute = ref.read(pendingNavigationRouteProvider);
      if (profile?.accountStatus == AccountStatus.active &&
          pendingRoute != null) {
        ref.read(pendingNavigationRouteProvider.notifier).state = null;
        router.go(pendingRoute);
      }
    });
    ref.listen<bool>(privacyModeEnabledProvider, (_, enabled) {
      _applyPrivacyMode();
    });
    ref.listen(currentAppUserProvider, (_, next) {
      final profile = next.asData?.value;
      _applyPrivacyMode(profile: profile);
      final uid = profile?.uid;
      if (profile?.accountStatus == AccountStatus.active && uid != null) {
        final uidChanged = _presenceUid != uid;
        _presenceUid = uid;
        if (uidChanged || _lastPresenceWrite == null) {
          _markActive(force: true);
        }
      }
    });
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      locale: const Locale('pl', 'PL'),
      supportedLocales: const [Locale('pl', 'PL')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _markActive(),
        onPointerMove: (_) => _markActive(),
        onPointerSignal: (_) => _markActive(),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }

  void _openNotificationRoute(String route) {
    final authUser = ref.read(authStateProvider).asData?.value;
    if (authUser == null) {
      ref.read(pendingNavigationRouteProvider.notifier).state = route;
      ref.read(appRouterProvider).go(RoutePaths.login);
      return;
    }
    ref.read(appRouterProvider).go(route);
  }

  void _applyPrivacyMode({AppUser? profile}) {
    final user = profile ?? ref.read(currentAppUserProvider).asData?.value;
    final adminSetting = ref.read(privacyModeEnabledProvider);
    final secure = switch (user?.role) {
      UserRole.admin => adminSetting,
      UserRole.moderator =>
        user?.moderatorCan('allowScreenshots') == true ? false : true,
      UserRole.user || null => true,
    };
    unawaited(PrivacyService.setSecureMode(secure));
  }

  void _markActive({bool force = false}) {
    final uid =
        ref.read(currentAppUserProvider).asData?.value?.uid ?? _presenceUid;
    if (uid == null || uid.isEmpty) return;
    final now = DateTime.now();
    final lastWrite = _lastPresenceWrite;
    if (!force &&
        lastWrite != null &&
        now.difference(lastWrite) < const Duration(seconds: 45)) {
      return;
    }
    _lastPresenceWrite = now;
    _presenceUid = uid;
    unawaited(
      ref
          .read(usersRepositoryProvider)
          .updatePresence(uid, PresenceStatus.online, manual: false)
          .catchError((Object error) {
            debugPrint('Presence update failed: $error');
          }),
    );
  }

  void _markOffline() {
    final uid = _presenceUid;
    if (uid == null || uid.isEmpty) return;
    unawaited(
      ref
          .read(usersRepositoryProvider)
          .updatePresence(uid, PresenceStatus.offline, manual: false)
          .catchError((Object error) {
            debugPrint('Presence offline update failed: $error');
          }),
    );
  }
}
