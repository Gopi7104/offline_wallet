import 'package:offline_wallet/core/money.dart';
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
      final balanceR = Money.fromPaise(response.paise);
      if (balanceR is! Ok) return null;
      _cached = Wallet(accountId: accountId, balance: balanceR.value);
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
    final balanceR = Money.fromPaise(response.newBalancePaise);
    if (balanceR is! Ok) throw Exception('Invalid balance from server');
    final newBalance = balanceR.value;
    _cached = Wallet(accountId: accountId, balance: newBalance);
    return newBalance;
  }
}
