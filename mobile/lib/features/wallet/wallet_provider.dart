import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/core/app_config.dart';
import 'package:offline_wallet/core/money.dart';
import 'package:offline_wallet/core/result.dart';
import 'package:offline_wallet/core/secure_storage.dart';
import 'package:offline_wallet/data/token_store.dart';
import 'package:offline_wallet/data/wallet_api_client_impl.dart';
import 'package:offline_wallet/data/wallet_repository_impl.dart';
import 'package:offline_wallet/domain/denominations.dart';
import 'package:offline_wallet/domain/token.dart';
import 'package:offline_wallet/domain/wallet.dart';
import 'package:offline_wallet/domain/wallet_repository.dart';
import 'package:offline_wallet/features/auth/auth_provider.dart';

/// Wallet state for Task 2. Simple in-memory state; Task 8+ adds
/// persistence and sync (ARCHITECTURE.md §8).

/// The account whose wallet + tokens we manage. Stubbed (matches the backend
/// account) until real session wiring exists.
const String kCustomerAccountId = 'test-account-1';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  final apiClient = WalletApiClientImpl(
    baseUrl: AppConfig.apiBaseUrl,
    identity: ref.read(identityHeadersProvider),
  );
  return WalletRepositoryImpl(apiClient: apiClient);
});

final walletProvider = FutureProvider<Wallet?>((ref) async {
  final repo = ref.watch(walletRepositoryProvider);
  return repo.getWallet('test-account-1');
});

final loadWalletProvider = FutureProvider.family<Money, int>((ref, amountPaise) async {
  final repo = ref.watch(walletRepositoryProvider);
  final amount = switch (Money.fromPaise(amountPaise)) {
    Ok(:final value) => value,
    Err(:final error) => throw error,
  };
  return repo.loadFunds(kCustomerAccountId, amount);
});

/// Local offline-cash token wallet (Task 8). Source of truth for the customer's
/// spendable tokens: minted on a successful Load, spent when an offline payment
/// completes. Persisted to secure storage so offline cash survives an app
/// restart (Task 9 upgrades this to the full encrypted Drift/SQLCipher store
/// with an op-counter). "Wallet owns tokens" per Architecture v1.1.
///
/// Persistence is best-effort: if the platform store is unavailable (e.g. under
/// `flutter test`) the wallet degrades to in-memory rather than throwing.
const String _kTokenWalletKey = 'offline_token_wallet_v1';

class TokenWalletNotifier extends StateNotifier<List<Token>> {
  final TokenMinter _minter;
  final SecureStore? _store;

  TokenWalletNotifier(this._minter, [this._store]) : super(const []) {
    _restore();
  }

  Money get balance => sumDenominations(state);

  /// Mint denomination tokens for [amountPaise] and add them to the wallet.
  void mint(int amountPaise) {
    final minted = _minter.mint(amountPaise, ownerId: kCustomerAccountId);
    if (minted.isEmpty) return;
    state = [...state, ...minted];
    _persist();
  }

  /// Remove tokens transferred out to a merchant (spent). Called only after a
  /// valid TRANSFER_COMPLETE — atomicity: value leaves the wallet exactly once.
  void spend(List<String> tokenIds) {
    final ids = tokenIds.toSet();
    state = state.where((t) => !ids.contains(t.id)).toList();
    _persist();
  }

  Future<void> _restore() async {
    final store = _store;
    if (store == null) return;
    try {
      final raw = await store.read(_kTokenWalletKey);
      if (raw == null || !mounted) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      state = decoded
          .map((e) => Token.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      // Corrupt/unavailable store — start empty rather than crash.
    }
  }

  void _persist() {
    final store = _store;
    if (store == null) return;
    final raw = jsonEncode(state.map((t) => t.toJson()).toList());
    store.write(_kTokenWalletKey, raw).catchError((_) {});
  }
}

final tokenMinterProvider = Provider<TokenMinter>((ref) => TokenMinter());

final tokenWalletProvider =
    StateNotifierProvider<TokenWalletNotifier, List<Token>>((ref) {
  return TokenWalletNotifier(
    ref.watch(tokenMinterProvider),
    ref.watch(appSecureStorageProvider),
  );
});

/// The customer's spendable offline-cash balance = Σ held token denominations.
final tokenBalanceProvider = Provider<Money>((ref) {
  return sumDenominations(ref.watch(tokenWalletProvider));
});
