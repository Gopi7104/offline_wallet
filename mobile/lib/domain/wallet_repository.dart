import 'package:offline_wallet/core/money.dart';
import 'wallet.dart';

/// WalletRepository — port for persistence (local DB, API, cache).
/// Domain defines the interface; data layer implements it.
abstract interface class WalletRepository {
  /// Fetch the current wallet (or null if not yet loaded).
  Future<Wallet?> getWallet(String accountId);

  /// Save wallet state locally (encrypted storage).
  Future<void> saveWallet(Wallet wallet);

  /// Load funds from the backend (bank simulator). Returns new balance.
  Future<Money> loadFunds(String accountId, Money amount);
}
