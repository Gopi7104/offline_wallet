import 'package:flutter/material.dart';
import 'package:offline_wallet/features/onboarding/splash_screen.dart';
import 'package:offline_wallet/theme/theme.dart';

/// Root widget. Routing, DI (Riverpod ProviderScope wraps this in main),
/// theming and localization live here (ARCHITECTURE.md §6.1 `app/`).
/// Task 6.5: boots into Splash, which routes to Onboarding/Auth/PIN
/// Setup/Home depending on persisted state; HomeScreen is the navigation hub
/// (Wallet, Pay, Merchant Mode) once through that gate.
class OfflineWalletApp extends StatelessWidget {
  const OfflineWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline Wallet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const SplashScreen(),
    );
  }
}
