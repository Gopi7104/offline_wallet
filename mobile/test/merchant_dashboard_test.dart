import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/domain/merchant.dart';
import 'package:offline_wallet/domain/merchant_repository.dart';
import 'package:offline_wallet/features/receive/merchant_dashboard_screen.dart';
import 'package:offline_wallet/features/receive/merchant_provider.dart';

/// In-memory fake so the widget test never touches the network. Records the
/// amount passed to each call so tests can assert Fixed vs Open requests.
class FakeMerchantRepository implements MerchantRepository {
  int qrCount = 0;
  int? lastAmountPaise;
  bool lastAmountPaiseWasSet = false;

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
    lastAmountPaise = amountPaise;
    lastAmountPaiseWasSet = true;
    return QrPayload(
      v: 1,
      merchantId: 'MER-ABC123DEF456',
      nonce: 'nonce-$qrCount',
      ts: 1752451200,
      amountPaise: amountPaise,
    );
  }
}

Future<ProviderContainer> _enabledContainer(FakeMerchantRepository fake) async {
  final container = ProviderContainer(
    overrides: [merchantRepositoryProvider.overrideWithValue(fake)],
  );
  await container.read(merchantModeProvider.notifier).enable();
  return container;
}

/// The dashboard (hero card + Payment Request card + Generated Request card +
/// Recent Requests) is taller than the default 800x600 test surface; a plain
/// `ListView` only builds children within its viewport + cache extent, so
/// without a larger surface the lower sections are never built and lookups
/// return zero — not "found but off-screen" (same fix as
/// wallet_funding_flow_test.dart's `_useTallSurface`).
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 4680);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  testWidgets('Merchant dashboard renders correctly: Merchant ID, wallet buckets, Payment Request section',
      (tester) async {
    _useTallSurface(tester);
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

    // Payment Request section: amount field, hint, and both action buttons.
    expect(find.byKey(const Key('payment-amount-field')), findsOneWidget);
    expect(find.text('Leave empty to let the customer enter the amount.'), findsOneWidget);
    expect(find.byKey(const Key('request-fixed-amount-button')), findsOneWidget);
    expect(find.byKey(const Key('request-open-amount-button')), findsOneWidget);

    // No Generated Payment Request card until a request is made.
    expect(find.byKey(const Key('qr-payload')), findsNothing);

    // Recent Requests placeholder rows.
    expect(find.text('Recent Requests'), findsOneWidget);
    expect(find.text('₹250'), findsOneWidget);
    expect(find.text('₹99'), findsOneWidget);
    expect(find.text('Open Amount'), findsOneWidget);
  });

  testWidgets('Merchant can create a Fixed Amount Request; QR displays the requested amount',
      (tester) async {
    _useTallSurface(tester);
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

    await tester.enterText(find.byKey(const Key('payment-amount-field')), '250');
    await tester.tap(find.byKey(const Key('request-fixed-amount-button')));
    await tester.pumpAndSettle();

    expect(fake.qrCount, 1);
    expect(fake.lastAmountPaise, 25000);

    expect(find.byKey(const Key('qr-payload')), findsOneWidget);
    expect(find.byKey(const Key('generated-amount-label')), findsOneWidget);
    expect(find.text('₹250'), findsWidgets); // requested amount + recent-requests seed row
    expect(find.text('Requested Amount'), findsOneWidget);
    expect(find.byKey(const Key('generated-status')), findsOneWidget);
    expect(find.text('Generated'), findsWidgets);
  });

  testWidgets('Merchant can create an Open Amount Request without entering an amount',
      (tester) async {
    _useTallSurface(tester);
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

    // Amount field left empty.
    await tester.tap(find.byKey(const Key('request-open-amount-button')));
    await tester.pumpAndSettle();

    expect(fake.qrCount, 1);
    expect(fake.lastAmountPaiseWasSet, true);
    expect(fake.lastAmountPaise, isNull);

    expect(find.byKey(const Key('qr-payload')), findsOneWidget);
    expect(find.text('Payment Type'), findsOneWidget);
    expect(find.byKey(const Key('generated-amount-label')), findsOneWidget);
  });

  testWidgets('Requesting a Fixed Amount without entering an amount shows a validation error',
      (tester) async {
    _useTallSurface(tester);
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

    await tester.tap(find.byKey(const Key('request-fixed-amount-button')));
    await tester.pumpAndSettle();

    expect(fake.qrCount, 0);
    expect(find.text('Enter an amount to request a fixed payment'), findsOneWidget);
    expect(find.byKey(const Key('qr-payload')), findsNothing);
  });
}
