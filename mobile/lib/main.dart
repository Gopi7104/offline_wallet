import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/firebase_options_placeholder.dart';
import 'features/auth/auth_provider.dart';
import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Task 6.5: no Firebase project is wired for this build. Init is guarded
  // so a missing/placeholder configuration never crashes the app — Guest
  // Mode always works; Email/Google/Apple sign-in show an honest "not
  // configured" notice instead (see firebase_options_placeholder.dart).
  bool firebaseReady = false;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    firebaseReady = true;
  } catch (_) {
    firebaseReady = false;
  }

  runApp(
    ProviderScope(
      overrides: [firebaseReadyProvider.overrideWithValue(firebaseReady)],
      child: const OfflineWalletApp(),
    ),
  );
}
