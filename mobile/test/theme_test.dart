import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/core/secure_storage.dart';
import 'package:offline_wallet/features/settings/settings_screen.dart';
import 'package:offline_wallet/features/settings/theme_provider.dart';
import 'package:offline_wallet/theme/app_theme.dart';
import 'package:offline_wallet/theme/colors.dart';

import 'pin_service_test.dart' show InMemorySecureStore;

void main() {
  group('AppTheme', () {
    test('builds a light and a dark ThemeData with the right brightness', () {
      expect(AppTheme.light().brightness, Brightness.light);
      expect(AppTheme.dark().brightness, Brightness.dark);
      // Brand color is shared across both themes (brightness-invariant).
      expect(AppTheme.light().colorScheme.primary, AppColors.primary);
      expect(AppTheme.dark().colorScheme.primary, AppColors.primary);
    });

    test('building both themes leaves the global brightness unchanged', () {
      AppColors.brightness = Brightness.dark;
      AppTheme.light();
      AppTheme.dark();
      expect(AppColors.brightness, Brightness.dark);
    });

    test('surface/text tokens flip with the active brightness', () {
      AppColors.brightness = Brightness.light;
      final lightBg = AppColors.background;
      final lightText = AppColors.textPrimary;
      AppColors.brightness = Brightness.dark;
      expect(AppColors.background, isNot(lightBg));
      expect(AppColors.textPrimary, isNot(lightText));
    });
  });

  group('ThemeModeNotifier', () {
    test('defaults to dark', () {
      final n = ThemeModeNotifier(InMemorySecureStore());
      expect(n.state, ThemeMode.dark);
    });

    test('setMode updates state and persists the choice', () async {
      final store = InMemorySecureStore();
      final n = ThemeModeNotifier(store);
      await n.setMode(ThemeMode.light);
      expect(n.state, ThemeMode.light);

      // A fresh notifier over the same store restores the persisted choice.
      final restored = ThemeModeNotifier(store);
      await Future<void>.delayed(Duration.zero); // let _load() run
      expect(restored.state, ThemeMode.light);
    });
  });

  group('Appearance selector (Settings)', () {
    testWidgets('renders three options with the persisted one selected, and switches',
        (tester) async {
      final store = InMemorySecureStore();
      final container = ProviderContainer(
        overrides: [appSecureStorageProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // All three appearance options are present.
      expect(find.byKey(const Key('theme-option-system')), findsOneWidget);
      expect(find.byKey(const Key('theme-option-light')), findsOneWidget);
      expect(find.byKey(const Key('theme-option-dark')), findsOneWidget);
      expect(find.text('Dark theme is on.'), findsOneWidget);

      // Tapping Light switches the mode.
      await tester.tap(find.byKey(const Key('theme-option-light')));
      await tester.pumpAndSettle();
      expect(container.read(themeModeProvider), ThemeMode.light);
      expect(find.text('Light theme is on.'), findsOneWidget);
    });
  });
}
