import 'package:firebase_core/firebase_core.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// TODO(auth): this file is a hand-written placeholder, not the real output
/// of `flutterfire configure`. No Firebase project is wired for this build
/// (Task 6.5 — see PROJECT_VISION.md / the plan doc for why). Firebase.
/// initializeApp() with these values will succeed (it just registers a
/// FirebaseApp instance), but any real Firebase Auth call will honestly fail
/// with "invalid API key" — by design, not a bug.
///
/// To wire a real project: run `flutterfire configure` from `mobile/`; it
/// overwrites this file with real per-platform options. Nothing else needs
/// to change — `main.dart` already imports `DefaultFirebaseOptions.currentPlatform`.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    if (Platform.isAndroid) return android;
    if (Platform.isIOS) return ios;
    return android;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'TODO-REPLACE-VIA-FLUTTERFIRE-CONFIGURE',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'offline-wallet-todo',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'TODO-REPLACE-VIA-FLUTTERFIRE-CONFIGURE',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'offline-wallet-todo',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'TODO-REPLACE-VIA-FLUTTERFIRE-CONFIGURE',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'offline-wallet-todo',
    iosBundleId: 'com.example.offlineWallet',
  );
}
