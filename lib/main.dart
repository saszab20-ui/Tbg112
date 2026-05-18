import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tarnobrzeg112/app.dart';
import 'package:tarnobrzeg112/firebase/firebase_bootstrap.dart';
import 'package:tarnobrzeg112/providers/firebase_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'pl_PL';
  await FirebaseBootstrap.initialize();

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
