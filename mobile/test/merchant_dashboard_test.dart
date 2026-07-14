import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/domain/merchant.dart';
import 'package:offline_wallet/domain/merchant_repository.dart';
import 'package:offline_wallet/features/receive/merchant_dashboard_screen.dart';
import 'package:offline_wallet/features/receive/merchant_provider.dart';

/// In-memory fake so the widget test never touches the network.
class FakeMerchantRepository implements MerchantRepository {
  int qrCount = 0;

  @override
  Future<Merchant> enableMerchantMode(String accountId, {String? displayName}) async {
    return Merchant(
      merchantId: 'MER-ABC123DEF456',
      accountId: accountId,
      displayName: 'Test Merchant',
      wallet: MerchantWallet.empty(),
    );
  }

  @override
  Future<Merchant?> getMerchant(String accountId) async => null;

  @override
  Future<QrPayload> generateQrPayload(String accountId, {int? amountPaise}) async {
    qrCount++;
    return QrPayload(
      v: 1,
      merchantId: 'MER-ABC123DEF456',
      nonce: 'nonce-$qrCount',
      ts: '2026-07-14T00:00:00.000Z',
      amountPaise: amountPaise,
    );
  }
}

void main() {
  testWidgets('dashboard shows Merchant ID and generates a placeholder QR payload',
      (tester) async {
    final fake = FakeMerchantRepository();
    final container = ProviderContainer(
      overrides: [merchantRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    // Enable Merchant Mode so the dashboard has a merchant to render.
    await container.read(merchantModeProvider.notifier).enable();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MerchantDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Merchant ID is displayed.
    expect(find.byKey(const Key('merchant-id')), findsOneWidget);
    expect(find.text('MER-ABC123DEF456'), findsOneWidget);

    // Wallet buckets shown, both zero.
    expect(find.byKey(const Key('pending-amount')), findsOneWidget);
    expect(find.byKey(const Key('settled-amount')), findsOneWidget);

    // No payload until the button is pressed.
    expect(find.byKey(const Key('qr-payload')), findsNothing);

    await tester.tap(find.byKey(const Key('generate-qr-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('qr-payload')), findsOneWidget);
    expect(find.textContaining('MER-ABC123DEF456'), findsWidgets);
    expect(fake.qrCount, 1);
  });
}
