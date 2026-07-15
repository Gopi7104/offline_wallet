import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/core/secure_storage.dart';
import 'biometric_service.dart';
import 'pin_service.dart';

/// Security feature state (Task 6.5): PIN status + biometrics availability
/// and the user's on/off preference for step-up payment auth.

final pinServiceProvider = Provider<PinService>((ref) {
  return PinService(storage: ref.watch(appSecureStorageProvider));
});

final biometricServiceProvider = Provider<BiometricService>((ref) => BiometricService());

/// Whether a PIN has been created. Watched by the app gate to decide whether
/// to route to PIN Setup or straight to Home.
final pinSetProvider = FutureProvider<bool>((ref) {
  return ref.watch(pinServiceProvider).isPinSet();
});

/// Whether this device has usable biometric hardware/enrollment.
final biometricsAvailableProvider = FutureProvider<bool>((ref) {
  return ref.watch(biometricServiceProvider).isAvailable();
});

const _biometricsEnabledKey = 'biometrics_enabled_v1';

/// User preference (Settings → Biometrics toggle), defaults to enabled.
/// Persisted so the choice survives app restarts.
class BiometricsEnabledNotifier extends StateNotifier<bool> {
  final SecureStore _storage;

  BiometricsEnabledNotifier(this._storage) : super(true) {
    _load();
  }

  Future<void> _load() async {
    final stored = await _storage.read(_biometricsEnabledKey);
    if (stored != null) state = stored == '1';
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await _storage.write(_biometricsEnabledKey, enabled ? '1' : '0');
  }
}

final biometricsEnabledProvider = StateNotifierProvider<BiometricsEnabledNotifier, bool>((ref) {
  return BiometricsEnabledNotifier(ref.watch(appSecureStorageProvider));
});
