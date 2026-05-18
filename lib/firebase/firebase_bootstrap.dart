import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:tarnobrzeg112/firebase/firebase_options.dart';

class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } on Object catch (error, stackTrace) {
      debugPrint('Firebase init failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }
}
