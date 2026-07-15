import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/core/app_config.dart';
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
  final apiClient = MerchantApiClientImpl(baseUrl: AppConfig.apiBaseUrl);
  return MerchantRepositoryImpl(apiClient: apiClient);
});

/// Controls the Merchant Mode toggle: null = off/unknown, data(Merchant) = on.
class MerchantModeNotifier extends StateNotifier<AsyncValue<Merchant?>> {
  final MerchantRepository _repository;

  MerchantModeNotifier(this._repository) : super(const AsyncValue.data(null));

  bool get isEnabled => state.valueOrNull != null;

  /// Enable Merchant Mode (idempotent server-side, FR-MER-01). If the backend
  /// is unreachable, fall back to a local merchant so the offline BLE receive
  /// flow still works without a server (Task 8 — the receive screen uses its
  /// own local merchant id for the QR/OFFER, so this identity is display-only;
  /// real registration lands with the backend in a later task).
  Future<void> enable() async {
    state = const AsyncValue.loading();
    try {
      final merchant = await _repository.enableMerchantMode(kMerchantAccountId);
      state = AsyncValue.data(merchant);
    } catch (_) {
      state = AsyncValue.data(_localMerchant());
    }
  }

  Merchant _localMerchant() => Merchant(
        merchantId: 'MER-LOCAL',
        accountId: kMerchantAccountId,
        displayName: 'Local Merchant (offline)',
        wallet: MerchantWallet.empty(),
      );

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
