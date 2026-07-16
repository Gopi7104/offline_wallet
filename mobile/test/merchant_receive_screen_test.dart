import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/features/receive/ble_merchant_provider.dart';
import 'package:offline_wallet/features/receive/merchant_receive_screen.dart';

import 'fake_ble_transports.dart';

/// Widget-level coverage for the Open Cash toggle added to the merchant
/// Receive Payment screen: the amount field disables and a fixed-amount
/// error is never shown when Open Cash is on, and starting advertises/shows a
/// QR either way. The underlying protocol behavior (OFFER contents, transfer
/// verification) is covered by `merchant_receive_test.dart`.
void main() {
  late LinkedPeripheral peripheral;

  Widget receiveScreen() => ProviderScope(
        overrides: [
          blePeripheralTransportProvider.overrideWithValue(peripheral),
        ],
        child: const MaterialApp(home: MerchantReceiveScreen()),
      );

  setUp(() => peripheral = LinkedPeripheral());
  tearDown(() => peripheral.dispose());

  testWidgets('Fixed Amount: entering an amount and starting shows the QR', (tester) async {
    await tester.pumpWidget(receiveScreen());

    await tester.enterText(find.byKey(const Key('receive-amount-field')), '250');
    await tester.tap(find.byKey(const Key('receive-start-button')));
    await tester.pump();

    expect(find.byKey(const Key('receive-qr')), findsOneWidget);
    expect(find.byKey(const Key('receive-amount-label')), findsOneWidget);
    expect(find.text('₹250.00'), findsOneWidget);
  });

  testWidgets('Fixed Amount: rejects a blank/zero amount with an inline error', (tester) async {
    await tester.pumpWidget(receiveScreen());

    await tester.tap(find.byKey(const Key('receive-start-button')));
    await tester.pump();

    expect(find.text('Enter a whole rupee amount greater than zero'), findsOneWidget);
    expect(find.byKey(const Key('receive-qr')), findsNothing);
  });

  testWidgets('Open Cash: toggling on disables the amount field and starts with no amount set',
      (tester) async {
    await tester.pumpWidget(receiveScreen());

    // Leave the amount field untouched — Open Cash should not need it.
    await tester.tap(find.byKey(const Key('receive-open-cash-switch')));
    await tester.pump();

    final amountField = tester.widget<TextField>(find.byKey(const Key('receive-amount-field')));
    expect(amountField.enabled, isFalse);

    await tester.tap(find.byKey(const Key('receive-start-button')));
    await tester.pump();

    // No validation error, and the requested-amount label reads "Open Cash"
    // until a transfer actually arrives.
    expect(find.text('Enter a whole rupee amount greater than zero'), findsNothing);
    expect(find.byKey(const Key('receive-qr')), findsOneWidget);
    expect(find.text('Open Cash'), findsOneWidget);
  });
}
