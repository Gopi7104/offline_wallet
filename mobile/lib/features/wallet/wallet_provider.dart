import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/core/app_config.dart';
import 'package:offline_wallet/core/money.dart';
import 'package:offline_wallet/core/result.dart';
import 'package:offline_wallet/data/wallet_api_client_impl.dart';
import 'package:offline_wallet/data/wallet_repository_impl.dart';
import 'package:offline_wallet/domain/wallet.dart';
import 'package:offline_wallet/domain/wallet_repository.dart';

/// Wallet state for Task 2. Simple in-memory state; Task 8+ adds
/// persistence and sync (ARCHITECTURE.md §8).

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  final apiClient = WalletApiClientImpl(baseUrl: AppConfig.apiBaseUrl);
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
  return repo.loadFunds('test-account-1', amount);
});
