import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/domain/merchant.dart';
import 'package:offline_wallet/features/pay/merchant_summary_screen.dart';

/// Task 6.7 customer flow: a Fixed Amount Payment Request already carries the
/// amount in the QR, so Continue must skip Amount Entry entirely; an Open
/// Amount Payment Request has no amount, so Continue must land on Amount
/// Entry so the payer can type one.
Widget _harness(QrPayload payload) => ProviderScope(
      child: MaterialApp(home: MerchantSummaryScreen(payload: payload)),
    );

void main() {
  testWidgets('Fixed Amount Request: summary shows the requested amount and skips amount entry',
      (tester) async {
    const payload = QrPayload(
      v: 1,
      merchantId: 'MER-ABC123DEF456',
      nonce: 'nonce-xyz',
      ts: 1752480000,
      amountPaise: 25000,
    );
    await tester.pumpWidget(_harness(payload));

    expect(find.byKey(const Key('summary-merchant-id')), findsOneWidget);
    expect(find.text('Requested amount'), findsOneWidget);
    expect(find.byKey(const Key('summary-amount')), findsOneWidget);
    expect(find.text('₹250.00'), findsOneWidget);
    expect(find.text('Continue to Pay'), findsOneWidget);

    await tester.tap(find.byKey(const Key('summary-continue')));
    await tester.pumpAndSettle();

    // Lands directly on Confirmation with the QR's amount — no Amount Entry.
    expect(find.byKey(const Key('amount-field')), findsNothing);
    expect(find.byKey(const Key('confirm-merchant-id')), findsOneWidget);
    expect(find.byKey(const Key('confirm-amount')), findsOneWidget);
    expect(find.text('₹250.00'), findsWidgets);
  });

  testWidgets('Open Amount Request: summary shows Open Amount and continues to amount entry',
      (tester) async {
    const payload = QrPayload(
      v: 1,
      merchantId: 'MER-ABC123DEF456',
      nonce: 'nonce-xyz',
      ts: 1752480000,
    );
    await tester.pumpWidget(_harness(payload));

    expect(find.byKey(const Key('summary-merchant-id')), findsOneWidget);
    expect(find.text('Payment type'), findsOneWidget);
    expect(find.byKey(const Key('summary-amount')), findsOneWidget);
    expect(find.text('Open Amount'), findsOneWidget);
    expect(find.text('Enter Amount'), findsOneWidget);

    await tester.tap(find.byKey(const Key('summary-continue')));
    await tester.pumpAndSettle();

    // Lands on Amount Entry — no Confirmation yet, no amount was skipped.
    expect(find.byKey(const Key('amount-field')), findsOneWidget);
    expect(find.byKey(const Key('confirm-amount')), findsNothing);
  });
}
