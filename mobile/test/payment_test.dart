import 'package:flutter_test/flutter_test.dart';
import 'package:offline_wallet/core/money.dart';
import 'package:offline_wallet/core/result.dart';
import 'package:offline_wallet/data/payment_api_client.dart';
import 'package:offline_wallet/domain/payment.dart';

Money rupees(int r) => switch (Money.fromRupees(r)) {
      Ok(:final value) => value,
      Err() => Money.zero(),
    };

void main() {
  group('Payment domain (Task 5)', () {
    test('PaymentRequest holds payer, merchant, amount and status', () {
      final pr = PaymentRequest(
        paymentRequestId: 'pr-1',
        payerAccountId: 'cust',
        merchantId: 'MER-1',
        merchantName: 'Shop',
        amount: rupees(25),
        status: 'CREATED',
      );
      expect(pr.amount.format(), '₹25.00');
      expect(pr.merchantName, 'Shop');
      expect(pr.status, 'CREATED');
    });
  });

  group('PaymentRequestResponse.fromJson', () {
    test('parses the wire contract', () {
      final r = PaymentRequestResponse.fromJson({
        'paymentRequestId': 'pr-9',
        'payerAccountId': 'cust-9',
        'merchantId': 'MER-ABC123DEF456',
        'merchantName': 'Corner Shop',
        'amount': {'paise': 3000, 'currency': 'INR'},
        'status': 'CREATED',
      });
      expect(r.paymentRequestId, 'pr-9');
      expect(r.merchantId, 'MER-ABC123DEF456');
      expect(r.amountPaise, 3000);
      expect(r.currency, 'INR');
      expect(r.status, 'CREATED');
    });
  });

  group('PaymentApiException', () {
    test('stringifies to the server message', () {
      final e = PaymentApiException(404, 'MERCHANT_NOT_FOUND', 'No merchant exists');
      expect(e.toString(), 'No merchant exists');
      expect(e.code, 'MERCHANT_NOT_FOUND');
    });
  });
}
