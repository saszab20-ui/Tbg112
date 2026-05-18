import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      TargetPlatform.macOS => macos,
      TargetPlatform.windows => windows,
      _ => android,
    };
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCqvJDPd_rkVDDSufXRnu4t-SLj4CW8L3Y',
    appId: '1:305918132110:android:6a3585d4812f9114f3aedf',
    messagingSenderId: '305918132110',
    projectId: 'tarnobrzeg-112',
    storageBucket: 'tarnobrzeg-112.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_IOS_API_KEY',
    appId: '1:000000000000:ios:tarnobrzeg112',
    messagingSenderId: '000000000000',
    projectId: 'tarnobrzeg-112',
    storageBucket: 'tarnobrzeg-112.firebasestorage.app',
    iosBundleId: 'pl.tarnobrzeg112.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'REPLACE_WITH_MACOS_API_KEY',
    appId: '1:000000000000:macos:tarnobrzeg112',
    messagingSenderId: '000000000000',
    projectId: 'tarnobrzeg-112',
    storageBucket: 'tarnobrzeg-112.firebasestorage.app',
    iosBundleId: 'pl.tarnobrzeg112.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_WITH_WEB_API_KEY',
    appId: '1:000000000000:web:tarnobrzeg112',
    messagingSenderId: '000000000000',
    projectId: 'tarnobrzeg-112',
    authDomain: 'tarnobrzeg-112.firebaseapp.com',
    storageBucket: 'tarnobrzeg-112.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'REPLACE_WITH_WINDOWS_API_KEY',
    appId: '1:000000000000:windows:tarnobrzeg112',
    messagingSenderId: '000000000000',
    projectId: 'tarnobrzeg-112',
    authDomain: 'tarnobrzeg-112.firebaseapp.com',
    storageBucket: 'tarnobrzeg-112.firebasestorage.app',
  );
}
