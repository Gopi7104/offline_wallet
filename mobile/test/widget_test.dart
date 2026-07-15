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

  @override
  Future<QrPayload> generateQrPayload(String accountId, {int? amountPaise}) async {
    return const QrPayload(v: 1, merchantId: 'MER-ABC123DEF456', nonce: 'n', ts: 1752480000);
  }
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
}
