import 'package:flutter/material.dart';
import 'package:offline_wallet/features/wallet/wallet_screen.dart';

/// Root widget. Routing, DI (Riverpod ProviderScope wraps this in main),
/// theming and localization live here (ARCHITECTURE.md §6.1 `app/`).
/// Task 2: Wire wallet screen. Later tasks add auth, pay, receive, history.
class OfflineWalletApp extends StatelessWidget {
  const OfflineWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline Wallet',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const WalletScreen(),
    );
  }
}
