import 'package:flutter/material.dart';

/// Root widget. Routing, DI (Riverpod ProviderScope wraps this in main),
/// theming and localization live here (ARCHITECTURE.md §6.1 `app/`).
/// Feature screens (auth, wallet, pay, receive, history) are wired in their
/// respective tasks.
class OfflineWalletApp extends StatelessWidget {
  const OfflineWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline Wallet',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const _SkeletonHome(),
    );
  }
}

class _SkeletonHome extends StatelessWidget {
  const _SkeletonHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offline Wallet')),
      body: const Center(
        child: Text('Skeleton — Architecture v1.1', key: Key('skeleton-banner')),
      ),
    );
  }
}
