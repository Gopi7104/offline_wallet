import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/domain/merchant.dart';
import 'package:offline_wallet/domain/merchant_repository.dart';
import 'package:offline_wallet/features/receive/merchant_dashboard_screen.dart';
import 'package:offline_wallet/features/receive/merchant_provider.dart';
import 'package:offline_wallet/features/receive/merchant_receive_screen.dart';

/// In-memory fake so the widget test never touches the network.
class FakeMerchantRepository implements MerchantRepository {
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
}

Future<ProviderContainer> _enabledContainer(FakeMerchantRepository fake) async {
  final container = ProviderContainer(
    overrides: [merchantRepositoryProvider.overrideWithValue(fake)],
  );
  await container.read(merchantModeProvider.notifier).enable();
  return container;
}

void main() {
  testWidgets('Merchant dashboard renders the Merchant ID, wallet buckets, and BLE receive nav',
      (tester) async {
    final fake = FakeMerchantRepository();
    final container = await _enabledContainer(fake);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MerchantDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Merchant Dashboard'), findsOneWidget);
    expect(find.byKey(const Key('merchant-id')), findsOneWidget);
    expect(find.text('MER-ABC123DEF456'), findsOneWidget);
    expect(find.byKey(const Key('pending-amount')), findsOneWidget);
    expect(find.byKey(const Key('settled-amount')), findsOneWidget);

    // The one payment flow: Receive Payment (BLE) — Fixed Amount or Open
    // Cash, QR + BLE advertising all live on that screen (no dashboard QR
    // generation feature anymore).
    expect(find.byKey(const Key('open-ble-merchant-button')), findsOneWidget);
  });

  testWidgets('Receive Payment (BLE) button navigates to the BLE receive screen', (tester) async {
    final fake = FakeMerchantRepository();
    final container = await _enabledContainer(fake);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MerchantDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-ble-merchant-button')));
    await tester.pumpAndSettle();

    expect(find.byType(MerchantReceiveScreen), findsOneWidget);
  });

  testWidgets('shows a placeholder when Merchant Mode is not enabled', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [merchantRepositoryProvider.overrideWithValue(FakeMerchantRepository())],
        child: const MaterialApp(home: MerchantDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('merchant-not-enabled')), findsOneWidget);
    expect(find.byKey(const Key('open-ble-merchant-button')), findsNothing);
  });
}
