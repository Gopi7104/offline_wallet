import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/data/merchant_api_client_impl.dart';
import 'package:offline_wallet/data/merchant_repository_impl.dart';
import 'package:offline_wallet/domain/merchant.dart';
import 'package:offline_wallet/domain/merchant_repository.dart';

/// Merchant Mode state (ARCHITECTURE.md §6.1 `receive/` — merchant role).
/// Task 4: enable Merchant Mode, read the dashboard, generate a placeholder QR.

/// The account whose Merchant Mode we manage. Stubbed for Task 4 (matches the
/// wallet feature); a later auth task supplies the real session account.
const String kMerchantAccountId = 'test-account-1';

final merchantRepositoryProvider = Provider<MerchantRepository>((ref) {
  final apiClient = MerchantApiClientImpl(baseUrl: 'http://localhost:3000');
  return MerchantRepositoryImpl(apiClient: apiClient);
});

/// Controls the Merchant Mode toggle: null = off/unknown, data(Merchant) = on.
class MerchantModeNotifier extends StateNotifier<AsyncValue<Merchant?>> {
  final MerchantRepository _repository;

  MerchantModeNotifier(this._repository) : super(const AsyncValue.data(null));

  bool get isEnabled => state.valueOrNull != null;

  /// Enable Merchant Mode (idempotent server-side, FR-MER-01).
  Future<void> enable() async {
    state = const AsyncValue.loading();
    try {
      final merchant = await _repository.enableMerchantMode(kMerchantAccountId);
      state = AsyncValue.data(merchant);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Turn the local toggle off. The backend has no "disable" in Task 4, so this
  /// only hides the dashboard; the Merchant ID persists server-side.
  void disable() {
    state = const AsyncValue.data(null);
  }
}

final merchantModeProvider =
    StateNotifierProvider<MerchantModeNotifier, AsyncValue<Merchant?>>((ref) {
  return MerchantModeNotifier(ref.watch(merchantRepositoryProvider));
});
