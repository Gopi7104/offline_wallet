import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/components/components.dart';
import 'package:offline_wallet/core/money.dart';
import 'package:offline_wallet/core/result.dart';
import 'package:offline_wallet/data/token_store.dart';
import 'package:offline_wallet/data/wallet_api_client.dart';
import 'package:offline_wallet/domain/token.dart';
import 'package:offline_wallet/domain/wallet.dart';
import 'package:offline_wallet/domain/wallet_repository.dart';
import 'package:offline_wallet/features/wallet/load_money/bank_account_screen.dart';
import 'package:offline_wallet/features/wallet/load_money/load_review_screen.dart';
import 'package:offline_wallet/features/wallet/load_money/upi_pin_screen.dart';
import 'package:offline_wallet/features/wallet/wallet_provider.dart';
import 'package:offline_wallet/features/wallet/wallet_screen.dart';

Money _money(int paise) => switch (Money.fromPaise(paise)) {
      Ok(:final value) => value,
      Err() => Money.zero(),
    };

/// Fake wallet repo: in-memory balance, counts load calls, optionally
/// simulates the backend rejecting a load for exceeding the holding cap
/// (FR-ISS-06) so the Processing screen's error handling can be exercised
/// without a real server.
class FakeWalletRepository implements WalletRepository {
  Money _balance;
  final bool failCap;
  int loadCalls = 0;

  FakeWalletRepository({int initialBalancePaise = 0, this.failCap = false})
      : _balance = _money(initialBalancePaise);

  @override
  Future<Wallet?> getWallet(String accountId) async => Wallet(accountId: accountId, balance: _balance);

  @override
  Future<void> saveWallet(Wallet wallet) async {}

  @override
  Future<List<Token>> loadFunds(String accountId, Money amount) async {
    loadCalls++;
    if (failCap) {
      throw WalletApiException(400, 'HOLDING_CAP_EXCEEDED', 'Load rejected: over the wallet holding cap');
    }
    _balance = _balance.add(amount);
    // Stands in for the backend's real signed tokens (Task 10) — the fake
    // doesn't talk to a server, but must still return real denomination
    // tokens summing to `amount`, since the production code now stores and
    // spends exactly what this returns (no local placeholder fallback).
    return TokenMinter().mint(amount.paise, ownerId: accountId);
  }
}

/// Roots the funding flow at `WalletScreen` under its real route name, so
/// `LoadSuccessScreen`/`LoadProcessingScreen`'s
/// `popUntil(ModalRoute.withName(WalletScreen.routeName))` resolves exactly
/// as it does in production (pushed from Home with that same name).
Widget _walletApp(WalletRepository repo) => ProviderScope(
      overrides: [walletRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        initialRoute: WalletScreen.routeName,
        routes: {WalletScreen.routeName: (_) => const WalletScreen()},
      ),
    );

Future<void> _tapDigits(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await tester.tap(find.text(d));
    await tester.pump();
  }
}

/// These screens are taller than the default 800x600 test surface (multi-step
/// forms with a keypad + two buttons below the fold); a plain `ListView`
/// only builds children within its viewport + cache extent, so without a
/// larger surface the bottom actions are never built and lookups by `Key`
/// return zero — not "found but off-screen". Logical size matches a real
/// phone's width (360, same as the physical device this was verified on) —
/// not just an oversized square — so a `Row` that overflows at real phone
/// width fails here too, instead of only surfacing on-device.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 4680);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

String _textOf(WidgetTester tester, Key key) => tester.widget<Text>(find.byKey(key)).data ?? '';

void main() {
  group('Load Money (amount entry)', () {
    testWidgets('quick amount selection fills the amount field and enables Continue', (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_walletApp(FakeWalletRepository()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('load-money-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick-amount-500')));
      await tester.pumpAndSettle();

      expect(find.text('500'), findsOneWidget);
      expect(
        tester.widget<PrimaryButton>(find.byKey(const Key('load-money-continue'))).onPressed,
        isNotNull,
      );
    });

    testWidgets('manual amount entry enables Continue and carries the right amount to Review',
        (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(_walletApp(FakeWalletRepository()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('load-money-button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('load-money-amount-field')), '750');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('load-money-continue')));
      await tester.pumpAndSettle();

      expect(_textOf(tester, const Key('review-amount')), '₹750.00');
    });

    testWidgets('Continue is disabled when the amount is invalid or exceeds the wallet cap',
        (tester) async {
      _useTallSurface(tester);
      // Current balance already near the cap: any positive load pushes it over.
      await tester.pumpWidget(_walletApp(FakeWalletRepository(initialBalancePaise: 4999900)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('load-money-button')));
      await tester.pumpAndSettle();

      // No amount entered yet — Continue disabled, no error shown.
      final continueBtn = find.byKey(const Key('load-money-continue'));
      expect(tester.widget<PrimaryButton>(continueBtn).onPressed, isNull);
      expect(find.byKey(const Key('load-money-error')), findsNothing);

      await tester.enterText(find.byKey(const Key('load-money-amount-field')), '500');
      await tester.pumpAndSettle();

      // ₹49,999 + ₹500 exceeds the ₹50,000 cap — error shown, Continue disabled.
      expect(find.byKey(const Key('load-money-error')), findsOneWidget);
      expect(tester.widget<PrimaryButton>(continueBtn).onPressed, isNull);
    });
  });

  group('Review screen', () {
    testWidgets('renders amount, balances, and the default bank account', (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(const MaterialApp(
        home: LoadReviewScreen(amountPaise: 50000, currentBalancePaise: 10000),
      ));
      await tester.pumpAndSettle();

      expect(_textOf(tester, const Key('review-amount')), '₹500.00');
      expect(_textOf(tester, const Key('review-current-balance')), '₹100.00');
      expect(_textOf(tester, const Key('review-projected-balance')), '₹600.00');
      expect(_textOf(tester, const Key('review-bank-account')), kDefaultBankAccount.displayLabel);
      expect(find.byKey(const Key('review-continue')), findsOneWidget);
    });
  });

  group('Bank account screen', () {
    testWidgets('renders placeholder accounts with radio selection', (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(const MaterialApp(
        home: BankAccountScreen(amountPaise: 50000, currentBalancePaise: 0),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(Key('bank-account-${kDefaultBankAccount.id}')), findsOneWidget);
      expect(find.text('State Bank of India'), findsOneWidget);
      expect(find.text('HDFC Bank'), findsOneWidget);
      expect(find.byType(Radio<String>), findsNWidgets(2));

      // Switching selection doesn't throw and Continue remains available.
      await tester.tap(find.text('HDFC Bank'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bank-account-continue')), findsOneWidget);
    });
  });

  group('UPI PIN screen', () {
    testWidgets('fewer than 6 digits shows a validation error; 6 digits proceeds', (tester) async {
      _useTallSurface(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [walletRepositoryProvider.overrideWithValue(FakeWalletRepository())],
        child: const MaterialApp(home: UpiPinScreen(amountPaise: 50000)),
      ));
      await tester.pumpAndSettle();

      await _tapDigits(tester, '1234');
      await tester.tap(find.byKey(const Key('upi-pin-verify')));
      await tester.pump();
      expect(find.byKey(const Key('upi-pin-error')), findsOneWidget);

      await _tapDigits(tester, '56');
      await tester.tap(find.byKey(const Key('upi-pin-verify')));
      // Two bare frames (not `pumpAndSettle`) — `pushReplacement` needs a
      // second frame for the new route's page to actually build, but the
      // fake repo resolves the load near-instantly, so settling all the way
      // through would race past Processing straight into Success before
      // this assertion runs.
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('processing-message')), findsOneWidget);
    });
  });

  group('End-to-end funding flow', () {
    testWidgets('successful load updates the wallet balance', (tester) async {
      _useTallSurface(tester);
      final repo = FakeWalletRepository(initialBalancePaise: 0);
      await tester.pumpWidget(_walletApp(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('load-money-button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('load-money-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick-amount-500')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('load-money-continue')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('review-continue')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('bank-account-continue')));
      await tester.pumpAndSettle();

      await _tapDigits(tester, '123456');
      await tester.tap(find.byKey(const Key('upi-pin-verify')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('load-success-title')), findsOneWidget);
      expect(_textOf(tester, const Key('load-success-amount')), '₹500.00');
      expect(_textOf(tester, const Key('load-success-new-balance')), '₹500.00');
      expect(repo.loadCalls, 1);

      await tester.tap(find.byKey(const Key('load-success-done')));
      await tester.pumpAndSettle();

      // Back on Wallet, showing the updated balance.
      expect(find.byKey(const Key('load-money-button')), findsOneWidget);
      expect(_textOf(tester, const Key('balance-display')), '₹500.00');
    });

    testWidgets('a wallet-cap rejection from the server shows an error dialog and returns to Wallet',
        (tester) async {
      _useTallSurface(tester);
      final repo = FakeWalletRepository(initialBalancePaise: 0, failCap: true);
      await tester.pumpWidget(_walletApp(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('load-money-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quick-amount-500')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('load-money-continue')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('review-continue')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bank-account-continue')));
      await tester.pumpAndSettle();
      await _tapDigits(tester, '123456');
      await tester.tap(find.byKey(const Key('upi-pin-verify')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Wallet limit exceeded'), findsOneWidget);
      expect(find.byKey(const Key('load-success-title')), findsNothing);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Error dismissed → back on Wallet, no success screen ever shown.
      expect(find.byKey(const Key('load-money-button')), findsOneWidget);
      expect(repo.loadCalls, 1);
    });
  });
}
