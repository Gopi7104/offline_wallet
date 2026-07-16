import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/data/token_store.dart';
import 'package:offline_wallet/features/pay/ble_customer_provider.dart';
import 'package:offline_wallet/features/pay/payment_confirmation_screen.dart';
import 'package:offline_wallet/features/pay/payment_transfer_screen.dart';
import 'package:offline_wallet/features/security/payment_step_up_provider.dart';
import 'package:offline_wallet/features/wallet/wallet_provider.dart';

import 'fake_ble_transports.dart';

/// Fake step-up gate — same DI seam as before. Defaults to approving.
class FakeStepUpAuthenticator implements PaymentStepUpAuthenticator {
  final bool approve;
  int calls = 0;
  FakeStepUpAuthenticator({this.approve = true});

  @override
  Future<bool> authenticate(BuildContext context, {required String reason}) async {
    calls++;
    return approve;
  }
}

void main() {
  // A wallet seeded with ₹250 of offline cash (₹200 + ₹50).
  TokenWalletNotifier seededWallet() => TokenWalletNotifier(TokenMinter())..mint(25000);

  Widget confirm({
    required FakeStepUpAuthenticator stepUp,
    required TokenWalletNotifier wallet,
    LinkedCentral? central,
    int amountPaise = 25000,
  }) =>
      ProviderScope(
        overrides: [
          paymentStepUpAuthenticatorProvider.overrideWithValue(stepUp),
          tokenWalletProvider.overrideWith((ref) => wallet),
          if (central != null) bleCentralTransportProvider.overrideWithValue(central),
        ],
        child: MaterialApp(
          home: PaymentConfirmationScreen(
            merchantId: 'MER-1',
            amountPaise: amountPaise,
            nonce: 'n-1',
          ),
        ),
      );

  testWidgets('sufficient balance + approved step-up advances to the transfer screen',
      (tester) async {
    final stepUp = FakeStepUpAuthenticator();
    final central = LinkedCentral();
    await tester.pumpWidget(confirm(stepUp: stepUp, wallet: seededWallet(), central: central));

    // Offline cash is shown.
    expect(find.byKey(const Key('confirm-offline-balance')), findsOneWidget);
    expect(find.text('₹250.00'), findsWidgets);

    await tester.tap(find.byKey(const Key('confirm-pay-button')));
    await tester.pump(); // run _onConfirm (auth) + push
    await tester.pump(); // build transfer screen + post-frame start()

    expect(stepUp.calls, 1);
    expect(find.byType(PaymentTransferScreen), findsOneWidget);
    expect(find.byKey(const Key('transfer-status')), findsOneWidget);

    // Tear down the tree so the session's pending timer is cancelled.
    await tester.pumpWidget(const SizedBox());
    central.dispose();
  });

  testWidgets('insufficient balance blocks before auth and shows an inline error',
      (tester) async {
    final stepUp = FakeStepUpAuthenticator();
    // Empty wallet.
    await tester.pumpWidget(confirm(stepUp: stepUp, wallet: TokenWalletNotifier(TokenMinter())));

    await tester.tap(find.byKey(const Key('confirm-pay-button')));
    await tester.pump();

    expect(find.byKey(const Key('confirm-error')), findsOneWidget);
    expect(stepUp.calls, 0); // never asked for auth
    expect(find.byType(PaymentTransferScreen), findsNothing);
  });

  testWidgets('declining the step-up blocks the payment (no transfer screen)',
      (tester) async {
    final stepUp = FakeStepUpAuthenticator(approve: false);
    await tester.pumpWidget(confirm(stepUp: stepUp, wallet: seededWallet()));

    await tester.tap(find.byKey(const Key('confirm-pay-button')));
    await tester.pump();
    await tester.pump();

    expect(stepUp.calls, 1);
    expect(find.byType(PaymentTransferScreen), findsNothing);
  });
}
