import 'package:offline_wallet/core/money.dart';
import 'package:offline_wallet/core/result.dart';
import 'package:offline_wallet/domain/wallet.dart';
import 'package:offline_wallet/domain/wallet_repository.dart';
import 'wallet_api_client.dart';

/// Concrete wallet repository (data layer). Manages wallet balance via API + cache.
/// Task 3: balance-only (tokens internal to backend).
/// Task 8+: will add local token storage (Drift+SQLCipher).
class WalletRepositoryImpl implements WalletRepository {
  final WalletApiClient apiClient;
  Wallet? _cached;

  WalletRepositoryImpl({required this.apiClient});

  @override
  Future<Wallet?> getWallet(String accountId) async {
    if (_cached != null) return _cached;
    try {
      final response = await apiClient.getWallet();
      final balance = switch (Money.fromPaise(response.paise)) {
        Ok(:final value) => value,
        Err() => null,
      };
      if (balance == null) return null;
      _cached = Wallet(accountId: accountId, balance: balance);
      return _cached;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> saveWallet(Wallet wallet) async {
    _cached = wallet;
  }

  @override
  Future<Money> loadFunds(String accountId, Money amount) async {
    final response = await apiClient.loadWallet(amount.paise);
    final newBalance = switch (Money.fromPaise(response.newBalancePaise)) {
      Ok(:final value) => value,
      Err() => throw Exception('Invalid balance from server'),
    };
    _cached = Wallet(accountId: accountId, balance: newBalance);
    return newBalance;
  }
}
