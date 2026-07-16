import 'package:firebase_core/firebase_core.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Android now points at the real `offline-wallet-ab2fc` Firebase project
/// (matches `android/app/google-services.json`) — see the Firebase Auth task.
/// iOS/web are NOT wired (no project registered for those platforms yet) and
/// remain hand-written placeholders: `Firebase.initializeApp()` succeeds
/// (it just registers a FirebaseApp instance) but any real Auth call on
/// those platforms will honestly fail with "invalid API key," by design.
///
/// To wire iOS/web: run `flutterfire configure` from `mobile/` after
/// registering those platforms in the Firebase console; it overwrites this
/// file with real per-platform options. Nothing else needs to change —
/// `main.dart` already imports `DefaultFirebaseOptions.currentPlatform`.
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
    apiKey: 'AIzaSyAJ2yfC5nsLkkcRId1UttfBj2Hb7IiXFco',
    appId: '1:863057766325:android:8309503bd768b1c5215bfc',
    messagingSenderId: '863057766325',
    projectId: 'offline-wallet-ab2fc',
    storageBucket: 'offline-wallet-ab2fc.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'TODO-REPLACE-VIA-FLUTTERFIRE-CONFIGURE',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'offline-wallet-todo',
    iosBundleId: 'com.example.offlineWallet',
  );
}
