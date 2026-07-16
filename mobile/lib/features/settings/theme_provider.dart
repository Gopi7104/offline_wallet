import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/core/secure_storage.dart';

/// App theme preference (Settings → Appearance). Persisted so the choice
/// survives restarts. Defaults to [ThemeMode.dark] — the app's original,
/// signature look — until the user picks otherwise.
///
/// Uses Flutter's built-in [ThemeMode] ({system, light, dark}); `system`
/// follows the OS setting, resolved against the platform brightness in
/// `app/app.dart`.
const _themeModeKey = 'theme_mode_v1';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SecureStore _storage;

  ThemeModeNotifier(this._storage) : super(ThemeMode.dark) {
    _load();
  }

  Future<void> _load() async {
    final stored = await _storage.read(_themeModeKey);
    final mode = _decode(stored);
    if (mode != null) state = mode;
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    await _storage.write(_themeModeKey, _encode(mode));
  }

  static String _encode(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'system',
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
      };

  static ThemeMode? _decode(String? value) => switch (value) {
        'system' => ThemeMode.system,
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => null,
      };
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref.watch(appSecureStorageProvider));
});
