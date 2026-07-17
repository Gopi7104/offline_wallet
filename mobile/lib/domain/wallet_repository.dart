import 'package:offline_wallet/core/money.dart';
import 'package:offline_wallet/domain/token.dart';
import 'wallet.dart';

/// WalletRepository — port for persistence (local DB, API, cache).
/// Domain defines the interface; data layer implements it.
abstract interface class WalletRepository {
  /// Fetch the current wallet (or null if not yet loaded).
  Future<Wallet?> getWallet(String accountId);

  /// Save wallet state locally (encrypted storage).
  Future<void> saveWallet(Wallet wallet);

  /// Load funds from the backend (bank simulator). Returns the exact,
  /// Ed25519-signed tokens the backend just issued (Task 10) — the caller
  /// stores these directly; there is no local re-minting.
  Future<List<Token>> loadFunds(String accountId, Money amount);
}
