import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:tarnobrzeg112/app.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';

// ignore: always_use_package_imports
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await initializeDateFormatting('pl_PL', null);
  Intl.defaultLocale = 'pl_PL';
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final container = ProviderContainer();
  try {
    await container.read(notificationServiceProvider).initialize();
  } on Object catch (error) {
    debugPrint('Notifications disabled until Firebase is configured: $error');
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const Tarnobrzeg112App(),
    ),
  );
}
