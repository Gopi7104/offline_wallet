import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/core/money.dart';
import 'package:offline_wallet/core/result.dart';
import 'package:offline_wallet/data/payment_api_client.dart';
import 'package:offline_wallet/domain/payment.dart';
import 'package:offline_wallet/domain/payment_repository.dart';
import 'package:offline_wallet/features/pay/pay_provider.dart';
import 'package:offline_wallet/features/pay/payment_confirmation_screen.dart';

Money _money(int paise) => switch (Money.fromPaise(paise)) {
      Ok(:final value) => value,
      Err() => Money.zero(),
    };

/// Fake repo: never touches the network. Either echoes a created request or
/// throws the backend's typed error.
class FakePaymentRepository implements PaymentRepository {
  final bool fail;
  FakePaymentRepository({this.fail = false});

  @override
  Future<PaymentRequest> createPaymentRequest({
    required String merchantId,
    required int amountPaise,
  }) async {
    if (fail) {
      throw PaymentApiException(404, 'MERCHANT_NOT_FOUND', 'No merchant exists for the given merchantId');
    }
    return PaymentRequest(
      paymentRequestId: 'pr-test',
      payerAccountId: 'test-account-1',
      merchantId: merchantId,
      merchantName: 'Test Merchant',
      amount: _money(amountPaise),
      status: 'CREATED',
    );
  }
}

Widget _confirm(FakePaymentRepository repo) => ProviderScope(
      overrides: [paymentRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(
        home: PaymentConfirmationScreen(merchantId: 'MER-ABC123DEF456', amountPaise: 2500),
      ),
    );

void main() {
  testWidgets('confirming a payment creates the request and shows the success screen',
      (tester) async {
    await tester.pumpWidget(_confirm(FakePaymentRepository()));

    // Confirmation shows the amount (₹25.00) and merchant.
    expect(find.byKey(const Key('confirm-amount')), findsOneWidget);
    expect(find.text('₹25.00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-pay-button')));
    await tester.pumpAndSettle();

    // Success screen with the backend-confirmed details.
    expect(find.byKey(const Key('success-title')), findsOneWidget);
    expect(find.byKey(const Key('success-merchant-name')), findsOneWidget);
    expect(find.text('Test Merchant'), findsOneWidget);
    expect(find.byKey(const Key('success-amount')), findsOneWidget);
    expect(find.text('₹25.00'), findsOneWidget);
  });

  testWidgets('a rejected payment surfaces the server error, no success screen',
      (tester) async {
    await tester.pumpWidget(_confirm(FakePaymentRepository(fail: true)));

    await tester.tap(find.byKey(const Key('confirm-pay-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('confirm-error')), findsOneWidget);
    expect(find.textContaining('No merchant exists'), findsOneWidget);
    expect(find.byKey(const Key('success-title')), findsNothing);
  });
}
