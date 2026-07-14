import 'package:flutter_test/flutter_test.dart';
import 'package:offline_wallet/core/money.dart';
import 'package:offline_wallet/core/result.dart';
import 'package:offline_wallet/domain/wallet.dart';

/// Type-safe unwrap for tests (Money has a private const constructor).
Money rupees(int r) => switch (Money.fromRupees(r)) {
      Ok(:final value) => value,
      Err() => Money.zero(),
    };

void main() {
  group('Wallet domain (Task 3: balance only, tokens hidden)', () {
    test('creates empty wallet', () {
      final w = Wallet.empty('alice');
      expect(w.accountId, 'alice');
      expect(w.balance.isZero, true);
    });

    test('wallet balance formatting', () {
      final balance = rupees(25);
      final w = Wallet(accountId: 'bob', balance: balance);
      expect(w.balance.format(), '₹25.00');
    });

    test('copyWithBalance creates new wallet immutably', () {
      final w1 = Wallet.empty('charlie');
      final newBalance = rupees(100);
      final w2 = w1.copyWithBalance(newBalance);

      expect(w1.balance.isZero, true); // immutable
      expect(w2.balance.paise, 10000);
      expect(w2.accountId, 'charlie');
    });

    test('equality compares accountId and balance', () {
      final w1 = Wallet(accountId: 'dave', balance: rupees(50));
      final w2 = Wallet(accountId: 'dave', balance: rupees(50));
      expect(w1, w2);
    });
  });
}
