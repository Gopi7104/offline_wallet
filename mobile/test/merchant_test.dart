import 'package:flutter_test/flutter_test.dart';
import 'package:offline_wallet/core/money.dart';
import 'package:offline_wallet/core/result.dart';
import 'package:offline_wallet/domain/merchant.dart';

/// Type-safe unwrap for tests (Money has a private const constructor).
Money rupees(int r) => switch (Money.fromRupees(r)) {
      Ok(:final value) => value,
      Err() => Money.zero(),
    };

void main() {
  group('Merchant domain (Task 4)', () {
    test('empty merchant wallet has zero buckets and zero total', () {
      final w = MerchantWallet.empty();
      expect(w.pendingSettlement.isZero, true);
      expect(w.settled.isZero, true);
      expect(w.total.isZero, true);
    });

    test('wallet total sums pending + settled', () {
      final w = MerchantWallet(
        pendingSettlement: rupees(200),
        settled: rupees(50),
      );
      expect(w.total.paise, 25000); // ₹250
    });

    test('merchant equality compares id/account/name/wallet', () {
      final a = Merchant(
        merchantId: 'MER-1',
        accountId: 'x',
        displayName: 'Store',
        wallet: MerchantWallet.empty(),
      );
      final b = Merchant(
        merchantId: 'MER-1',
        accountId: 'x',
        displayName: 'Store',
        wallet: MerchantWallet.empty(),
      );
      expect(a, b);
    });

    test('qr payload holds the placeholder wire fields', () {
      const p = QrPayload(
        v: 1,
        merchantId: 'MER-1',
        nonce: 'n',
        ts: 1752480000,
        amountPaise: 100,
      );
      expect(p.v, 1);
      expect(p.typ, 'offer-req');
      expect(p.merchantId, 'MER-1');
      expect(p.nonce, 'n');
      expect(p.ts, 1752480000);
      expect(p.amountPaise, 100);
    });

    test('isFixedAmount reflects a Fixed vs Open Amount Payment Request (Task 6.7)', () {
      const fixed = QrPayload(v: 1, merchantId: 'MER-1', nonce: 'n', ts: 1, amountPaise: 25000);
      const open = QrPayload(v: 1, merchantId: 'MER-1', nonce: 'n', ts: 1);
      expect(fixed.isFixedAmount, true);
      expect(open.isFixedAmount, false);
    });
  });
}
