import 'package:offline_wallet/core/money.dart';
import 'package:offline_wallet/core/result.dart';
import 'package:offline_wallet/domain/merchant.dart';
import 'package:offline_wallet/domain/merchant_repository.dart';
import 'merchant_api_client.dart';

/// Concrete merchant repository (data layer). Maps wire DTOs → domain entities
/// and caches the current merchant. Task 4: no local persistence yet.
class MerchantRepositoryImpl implements MerchantRepository {
  final MerchantApiClient apiClient;
  Merchant? _cached;

  MerchantRepositoryImpl({required this.apiClient});

  @override
  Future<Merchant> enableMerchantMode(String accountId, {String? displayName}) async {
    final response = await apiClient.enable(displayName: displayName);
    final merchant = _toDomain(response);
    _cached = merchant;
    return merchant;
  }

  @override
  Future<Merchant?> getMerchant(String accountId) async {
    if (_cached != null) return _cached;
    final response = await apiClient.getMerchant();
    if (response == null) return null;
    _cached = _toDomain(response);
    return _cached;
  }

  Merchant _toDomain(MerchantResponse r) {
    return Merchant(
      merchantId: r.merchantId,
      accountId: r.accountId,
      displayName: r.displayName,
      wallet: MerchantWallet(
        pendingSettlement: _money(r.pendingSettlementPaise),
        settled: _money(r.settledPaise),
      ),
    );
  }

  Money _money(int paise) {
    // The server never sends negatives; treat any invalid amount as zero.
    return switch (Money.fromPaise(paise)) {
      Ok(:final value) => value,
      Err() => Money.zero(),
    };
  }
}
