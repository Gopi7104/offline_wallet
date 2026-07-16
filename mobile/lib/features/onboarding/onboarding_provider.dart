import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/core/secure_storage.dart';

const _onboardingSeenKey = 'onboarding_seen_v1';

/// Whether the user has been through the 3-page onboarding once. Persisted so
/// it only shows on first launch.
class OnboardingSeenNotifier extends StateNotifier<AsyncValue<bool>> {
  final SecureStore _storage;

  OnboardingSeenNotifier(this._storage) : super(const AsyncValue.loading()) {
    _load();
  }

  /// Test/preview seam — see `AuthController.seeded`.
  OnboardingSeenNotifier.seeded(this._storage, bool seen) : super(AsyncValue.data(seen));

  Future<void> _load() async {
    final value = await _storage.read(_onboardingSeenKey);
    state = AsyncValue.data(value == '1');
  }

  Future<void> markSeen() async {
    await _storage.write(_onboardingSeenKey, '1');
    state = const AsyncValue.data(true);
  }
}

final onboardingSeenProvider = StateNotifierProvider<OnboardingSeenNotifier, AsyncValue<bool>>((ref) {
  return OnboardingSeenNotifier(ref.watch(appSecureStorageProvider));
});
