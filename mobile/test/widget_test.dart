import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/app/app.dart';
import 'package:offline_wallet/domain/merchant.dart';
import 'package:offline_wallet/domain/merchant_repository.dart';
import 'package:offline_wallet/features/receive/merchant_provider.dart';

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
    return const QrPayload(v: 1, merchantId: 'MER-ABC123DEF456', nonce: 'n', ts: 't');
  }
}

void main() {
  testWidgets('home boots with wallet + merchant toggle; enabling reveals dashboard nav',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          merchantRepositoryProvider.overrideWithValue(FakeMerchantRepository()),
        ],
        child: const OfflineWalletApp(),
      ),
    );

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
