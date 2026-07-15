import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/core/money.dart';
import 'package:offline_wallet/domain/wallet.dart';
import 'package:offline_wallet/domain/wallet_repository.dart';
import 'package:offline_wallet/features/wallet/wallet_provider.dart';
import 'package:offline_wallet/features/wallet/wallet_screen.dart';

/// Fake that COUNTS load calls so we can prove opening the screen never loads.
class FakeWalletRepository implements WalletRepository {
  int loadCalls = 0;
  Money _balance = Money.zero();

  @override
  Future<Wallet?> getWallet(String accountId) async =>
      Wallet(accountId: accountId, balance: _balance);

  @override
  Future<void> saveWallet(Wallet wallet) async {}

  @override
  Future<Money> loadFunds(String accountId, Money amount) async {
    loadCalls++;
    _balance = _balance.add(amount);
    return _balance;
  }
}

Widget _screen(FakeWalletRepository repo) => ProviderScope(
      overrides: [walletRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: WalletScreen()),
    );

void main() {
  testWidgets('opening the Wallet screen does NOT load money (QA fix)', (tester) async {
    final repo = FakeWalletRepository();
    await tester.pumpWidget(_screen(repo));
    await tester.pumpAndSettle();

    // Screen rendered, balance shown, and crucially: no load was triggered.
    expect(find.byKey(const Key('balance-display')), findsOneWidget);
    expect(find.byKey(const Key('load-money-button')), findsOneWidget);
    expect(repo.loadCalls, 0);
  });

  testWidgets('pressing Load Money opens the funding flow (amount entry), no load yet',
      (tester) async {
    final repo = FakeWalletRepository();
    await tester.pumpWidget(_screen(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('load-money-button')));
    await tester.pumpAndSettle();

    // Now on the Load Money (amount entry) screen — the actual load call
    // only happens after Review → Bank Account → UPI PIN (Task 6.6).
    expect(find.text('Load Money'), findsOneWidget);
    expect(find.byKey(const Key('load-money-continue')), findsOneWidget);
    expect(repo.loadCalls, 0);
  });
}
