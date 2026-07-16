import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/app/app.dart';
import 'package:offline_wallet/domain/merchant.dart';
import 'package:offline_wallet/domain/merchant_repository.dart';
import 'package:offline_wallet/features/auth/auth_provider.dart';
import 'package:offline_wallet/features/auth/auth_service.dart';
import 'package:offline_wallet/features/onboarding/onboarding_provider.dart';
import 'package:offline_wallet/features/receive/merchant_provider.dart';
import 'package:offline_wallet/features/security/security_provider.dart';
import 'package:offline_wallet/core/money.dart';
import 'package:offline_wallet/domain/wallet.dart';
import 'package:offline_wallet/domain/wallet_repository.dart';
import 'package:offline_wallet/features/wallet/wallet_provider.dart';
import 'auth_session_test.dart' show FakeAuthService;
import 'pin_service_test.dart' show InMemorySecureStore;

/// In-memory fake so the home test never touches the network for wallet data.
class FakeWalletRepository implements WalletRepository {
  @override
  Future<Wallet?> getWallet(String accountId) async => Wallet(accountId: accountId, balance: Money.zero());

  @override
  Future<void> saveWallet(Wallet wallet) async {}

  @override
  Future<Money> loadFunds(String accountId, Money amount) async => amount;
}

/// In-memory fake so the home test never touches the network.
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

void main() {
  testWidgets('home boots with wallet + merchant toggle; enabling reveals dashboard nav',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          merchantRepositoryProvider.overrideWithValue(FakeMerchantRepository()),
          // Skip Splash → Onboarding → Auth → PIN Setup: seed a returning,
          // fully-onboarded guest so the app gate lands straight on Home.
          onboardingSeenProvider.overrideWith(
            (ref) => OnboardingSeenNotifier.seeded(InMemorySecureStore(), true),
          ),
          authControllerProvider.overrideWith(
            (ref) => AuthController.seeded(
              FakeAuthService(),
              InMemorySecureStore(),
              const AuthSessionState(status: AuthStatus.guest, user: AppUser(uid: 'test-guest', isGuest: true)),
            ),
          ),
          pinSetProvider.overrideWith((ref) => Future.value(true)),
          walletRepositoryProvider.overrideWithValue(FakeWalletRepository()),
        ],
        child: const OfflineWalletApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Boots on the Home screen.
    expect(find.text('Offline Wallet'), findsOneWidget);
    expect(find.byKey(const Key('open-wallet')), findsOneWidget);
    expect(find.byKey(const Key('open-pay')), findsOneWidget);
    expect(find.byKey(const Key('merchant-mode-toggle')), findsOneWidget);

    // Merchant Mode starts off — no dashboard nav yet.
    expect(find.byKey(const Key('open-merchant-dashboard')), findsNothing);

    // Toggle Merchant Mode on → enables → dashboard nav appears.
    await tester.tap(find.byKey(const Key('merchant-mode-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('open-merchant-dashboard')), findsOneWidget);
  });

  testWidgets('Home greets a named user by name, not their email', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          merchantRepositoryProvider.overrideWithValue(FakeMerchantRepository()),
          onboardingSeenProvider.overrideWith(
            (ref) => OnboardingSeenNotifier.seeded(InMemorySecureStore(), true),
          ),
          authControllerProvider.overrideWith(
            (ref) => AuthController.seeded(
              FakeAuthService(),
              InMemorySecureStore(),
              const AuthSessionState(
                status: AuthStatus.authenticated,
                user: AppUser(uid: 'u-1', email: 'jane@user.com', displayName: 'Jane Doe'),
              ),
            ),
          ),
          pinSetProvider.overrideWith((ref) => Future.value(true)),
          walletRepositoryProvider.overrideWithValue(FakeWalletRepository()),
        ],
        child: const OfflineWalletApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('jane@user.com'), findsNothing);
  });

  testWidgets('Home falls back to email when displayName is blank, not a blank greeting', (tester) async {
    // Regression: accounts whose profile was never given a name (e.g.
    // created directly in the Firebase console) can have displayName set to
    // "" rather than null — `??` alone treats "" as present and greets with
    // nothing at all.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          merchantRepositoryProvider.overrideWithValue(FakeMerchantRepository()),
          onboardingSeenProvider.overrideWith(
            (ref) => OnboardingSeenNotifier.seeded(InMemorySecureStore(), true),
          ),
          authControllerProvider.overrideWith(
            (ref) => AuthController.seeded(
              FakeAuthService(),
              InMemorySecureStore(),
              const AuthSessionState(
                status: AuthStatus.authenticated,
                user: AppUser(uid: 'u-1', email: 'blank-name@user.com', displayName: ''),
              ),
            ),
          ),
          pinSetProvider.overrideWith((ref) => Future.value(true)),
          walletRepositoryProvider.overrideWithValue(FakeWalletRepository()),
        ],
        child: const OfflineWalletApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('blank-name@user.com'), findsOneWidget);
  });
}
