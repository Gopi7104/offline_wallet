import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/core/money.dart';
import 'package:offline_wallet/core/result.dart';
import 'package:offline_wallet/data/token_store.dart';
import 'package:offline_wallet/domain/settlement.dart';
import 'package:offline_wallet/domain/token.dart';
import 'package:offline_wallet/features/receive/pending_settlement_provider.dart';
import 'package:offline_wallet/features/receive/settlement_provider.dart';
import 'package:offline_wallet/features/receive/settlement_screen.dart';

/// In-memory fake so widget tests never touch the network. Returns a canned
/// result or throws a canned [SettlementException].
class FakeSettlementRepository implements SettlementRepository {
  SettlementResult? nextResult;
  SettlementException? nextError;
  int calls = 0;
  List<Token>? lastTokens;

  @override
  Future<SettlementResult> settle(String merchantId, List<Token> tokens) async {
    calls++;
    lastTokens = tokens;
    if (nextError != null) throw nextError!;
    return nextResult!;
  }
}

Money _money(int paise) => switch (Money.fromPaise(paise)) {
      Ok(:final value) => value,
      Err() => Money.zero(),
    };

SettlementResult _result({
  int accepted = 0,
  int rejected = 0,
  int duplicates = 0,
  int creditedPaise = 0,
  String settlementId = 'SET-TEST-1',
  String ledgerId = 'LED-TEST-1',
  SettlementStatus status = SettlementStatus.success,
}) =>
    SettlementResult(
      settlementId: settlementId,
      accepted: accepted,
      rejected: rejected,
      duplicates: duplicates,
      creditedAmount: _money(creditedPaise),
      ledgerId: ledgerId,
      status: status,
    );

/// The summary card is taller than the default 800x600 test surface; grow it
/// so a ListView builds every row (same fix as merchant_dashboard_test.dart).
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 5200);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<ProviderContainer> _pumpScreen(
  WidgetTester tester, {
  required FakeSettlementRepository fake,
  required List<Token> pending,
}) async {
  final container = ProviderContainer(
    overrides: [settlementRepositoryProvider.overrideWithValue(fake)],
  );
  addTearDown(container.dispose);
  container.read(pendingSettlementProvider.notifier).addTokens(pending);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettlementScreen(merchantId: 'MER-TEST')),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  final tokens = TokenMinter().mint(25000, ownerId: 'payer-1'); // ₹250 → 2 tokens

  testWidgets('settlement screen renders Pending Settlement and a Settle Now button',
      (tester) async {
    _useTallSurface(tester);
    final fake = FakeSettlementRepository();
    await _pumpScreen(tester, fake: fake, pending: tokens);

    expect(find.text('Settlement'), findsOneWidget);
    expect(find.byKey(const Key('settlement-pending-amount')), findsOneWidget);
    expect(find.text('₹250.00'), findsWidgets);
    expect(find.byKey(const Key('settlement-pending-count')), findsOneWidget);
    expect(find.text('${tokens.length}'), findsWidgets);
    expect(find.byKey(const Key('settle-now-button')), findsOneWidget);
    expect(find.byKey(const Key('settlement-summary')), findsNothing);
  });

  testWidgets('successful settlement shows the summary with credited amount, counts and ids',
      (tester) async {
    _useTallSurface(tester);
    final fake = FakeSettlementRepository()
      ..nextResult = _result(
        accepted: 2,
        creditedPaise: 25000,
        settlementId: 'SET-ABC',
        ledgerId: 'LED-XYZ',
        status: SettlementStatus.success,
      );
    await _pumpScreen(tester, fake: fake, pending: tokens);

    await tester.tap(find.byKey(const Key('settle-now-button')));
    await tester.pumpAndSettle();

    expect(fake.calls, 1);
    expect(fake.lastTokens!.length, tokens.length);

    expect(find.byKey(const Key('settlement-summary')), findsOneWidget);
    expect(find.byKey(const Key('summary-credited')), findsOneWidget);
    expect(find.text('₹250.00'), findsWidgets);
    expect(find.byKey(const Key('summary-accepted')), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.byKey(const Key('summary-settlement-id')), findsOneWidget);
    expect(find.text('SET-ABC'), findsOneWidget);
    expect(find.text('LED-XYZ'), findsOneWidget);
    expect(find.byKey(const Key('summary-status')), findsOneWidget);
    expect(find.text('Settled'), findsOneWidget);
  });

  testWidgets('duplicate detection surfaces in the summary (rejected, nothing credited)',
      (tester) async {
    _useTallSurface(tester);
    final fake = FakeSettlementRepository()
      ..nextResult = _result(
        accepted: 0,
        duplicates: 2,
        creditedPaise: 0,
        status: SettlementStatus.rejected,
      );
    await _pumpScreen(tester, fake: fake, pending: tokens);

    await tester.tap(find.byKey(const Key('settle-now-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settlement-summary')), findsOneWidget);
    expect(find.byKey(const Key('summary-duplicates')), findsOneWidget);
    // Duplicate count = 2, credited ₹0.00, status Rejected.
    final duplicatesText = tester.widget<Text>(find.byKey(const Key('summary-duplicates')));
    expect(duplicatesText.data, '2');
    final creditedText = tester.widget<Text>(find.byKey(const Key('summary-credited')));
    expect(creditedText.data, '₹0.00');
    expect(find.text('Rejected'), findsOneWidget);
  });

  testWidgets('pending settlement is cleared after a successful settlement',
      (tester) async {
    _useTallSurface(tester);
    final fake = FakeSettlementRepository()
      ..nextResult = _result(accepted: 2, creditedPaise: 25000, status: SettlementStatus.success);
    final container = await _pumpScreen(tester, fake: fake, pending: tokens);

    expect(container.read(pendingSettlementProvider).pending, isNotEmpty);

    await tester.tap(find.byKey(const Key('settle-now-button')));
    await tester.pumpAndSettle();

    final state = container.read(pendingSettlementProvider);
    expect(state.pending, isEmpty);
    expect(state.hasPending, isFalse);
    // Credited amount moved to the settled bucket.
    expect(state.settled.paise, 25000);
  });

  testWidgets('an unknown-merchant failure shows a Material dialog and keeps pending intact',
      (tester) async {
    _useTallSurface(tester);
    final fake = FakeSettlementRepository()
      ..nextError = const SettlementException(SettlementErrorKind.unknownMerchant);
    final container = await _pumpScreen(tester, fake: fake, pending: tokens);

    await tester.tap(find.byKey(const Key('settle-now-button')));
    await tester.pumpAndSettle();

    expect(find.text('Settlement failed'), findsOneWidget);
    expect(find.text(SettlementErrorKind.unknownMerchant.message), findsOneWidget);
    // Nothing settled: pending survives so the merchant can retry.
    expect(container.read(pendingSettlementProvider).pending, isNotEmpty);
    expect(find.byKey(const Key('settlement-summary')), findsNothing);
  });

  test('PendingSettlementNotifier: addTokens is idempotent by token id', () {
    final notifier = PendingSettlementNotifier();
    notifier.addTokens(tokens);
    notifier.addTokens(tokens); // same ids again
    expect(notifier.state.pendingCount, tokens.length);
  });
}
