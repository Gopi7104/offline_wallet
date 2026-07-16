import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/features/onboarding/splash_screen.dart';
import 'package:offline_wallet/features/settings/theme_provider.dart';
import 'package:offline_wallet/theme/theme.dart';

/// Root widget. Routing, DI (Riverpod ProviderScope wraps this in main),
/// theming and localization live here (ARCHITECTURE.md §6.1 `app/`).
///
/// Appearance: both light and dark themes are supplied and selected by the
/// user's persisted [themeModeProvider] choice (Settings → Appearance), with
/// `system` following the OS. The root `builder` mirrors the active brightness
/// into [AppColors] so custom widgets that read the palette directly stay in
/// lock-step with the Material theme Flutter rendered.
class OfflineWalletApp extends ConsumerWidget {
  const OfflineWalletApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Offline Wallet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      builder: (context, child) {
        // Keep the direct-access palette aligned with the rendered theme.
        AppColors.brightness = Theme.of(context).brightness;
        return child ?? const SizedBox.shrink();
      },
      home: const SplashScreen(),
    );
  }
}
