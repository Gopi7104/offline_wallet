import 'package:flutter_test/flutter_test.dart';
import 'package:offline_wallet/core/crypto/device_keypair_store.dart';
import 'package:offline_wallet/core/money.dart';
import 'package:offline_wallet/core/result.dart';
import 'package:offline_wallet/data/token_store.dart';
import 'package:offline_wallet/data/wallet_api_client.dart';
import 'package:offline_wallet/data/wallet_repository_impl.dart';
import 'package:offline_wallet/domain/qr_codec.dart';
import 'package:offline_wallet/domain/token.dart';
import 'package:offline_wallet/features/pay/payment_session_controller.dart';
import 'package:offline_wallet/features/receive/merchant_receive_controller.dart';
import 'package:offline_wallet/features/wallet/wallet_provider.dart';
import 'package:offline_wallet/platform/ble/ble_permission_service.dart';

import 'fake_ble_transports.dart';
import 'fake_secure_store.dart';

/// Task 10 end-to-end proof: the wallet stores and spends the EXACT tokens a
/// `POST /v1/wallet/load` response carries — never a locally-minted
/// placeholder. Fakes only the network boundary (`WalletApiClient`); every
/// other component (`WalletRepositoryImpl`, `TokenWalletNotifier`,
/// `PaymentSessionController`, `MerchantReceiveController`) is the real
/// production class, wired exactly as `wallet_provider.dart` wires it.
///
/// `_PoisonedTokenMinter` makes the "no placeholder" assertion self-enforcing:
/// if the production load path ever regresses to calling `mint()` again,
/// this test fails with a clear error instead of silently passing.
class _PoisonedTokenMinter extends TokenMinter {
  @override
  List<Token> mint(int amountPaise, {required String ownerId}) {
    throw StateError('production Load Money path must not use the placeholder minter');
  }
}

Money _money(int paise) => switch (Money.fromPaise(paise)) {
      Ok(:final value) => value,
      Err() => Money.zero(),
    };

const String _issuerSig1 =
    'f1e2d3c4b5a697887766554433221100ffeeddccbbaa99887766554433221100ffeeddccbbaa998877665544332211ff';
const String _issuerSig2 =
    '0011223344556677889900aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccdd11';

/// Stands in for the real backend: `loadWallet` returns a wire-shaped
/// response identical to what `WalletController.loadWallet` sends —
/// `{id, denom, owner, iat, exp, status, sig}` per token, each `sig` a
/// realistic (non-placeholder) 128-char hex issuer signature — built from a
/// raw JSON map and parsed through the real `LoadResponse.fromJson`/
/// `Token.fromJson`, the same parsing code path `WalletApiClientImpl` uses on
/// a real HTTP response.
class FakeBackendWalletApiClient implements WalletApiClient {
  @override
  Future<WalletResponse> getWallet() async =>
      WalletResponse(accountId: 'test-account-1', paise: 0, currency: 'INR');

  @override
  Future<LoadResponse> loadWallet(int amountPaise) async {
    final now = DateTime.now();
    final iat = now.millisecondsSinceEpoch ~/ 1000;
    final exp = now.add(const Duration(days: 30)).millisecondsSinceEpoch ~/ 1000;
    return LoadResponse.fromJson({
      'accountId': 'test-account-1',
      'newBalance': {'paise': amountPaise, 'currency': 'INR'},
      'tokens': [
        {
          'id': 'backend-issued-b7e2b1b0-4a3d-4f1a-9c2e-tok1',
          'denom': 20000,
          'owner': 'test-account-1',
          'iat': iat,
          'exp': exp,
          'status': 'in_wallet',
          'sig': _issuerSig1,
        },
        {
          'id': 'backend-issued-a441cabe-8d7c-4e2b-8a1f-tok2',
          'denom': 5000,
          'owner': 'test-account-1',
          'iat': iat,
          'exp': exp,
          'status': 'in_wallet',
          'sig': _issuerSig2,
        },
      ],
    });
  }
}

Future<void> _tick() => Future<void>.delayed(Duration.zero);

void main() {
  test(
      'backend-issued tokens are stored verbatim, survive an app restart, and are the exact '
      'tokens an offline payment delivers to the merchant', () async {
    final repo = WalletRepositoryImpl(apiClient: FakeBackendWalletApiClient());
    final store = FakeSecureStore();

    // ── Load Money ──────────────────────────────────────────────────────
    final wallet = TokenWalletNotifier(_PoisonedTokenMinter(), store);
    await _tick();
    final issuedTokens = await repo.loadFunds('test-account-1', _money(25000));
    wallet.addTokens(issuedTokens);
    await _tick();

    expect(wallet.balance.paise, 25000);
    const expectedIds = {
      'backend-issued-b7e2b1b0-4a3d-4f1a-9c2e-tok1',
      'backend-issued-a441cabe-8d7c-4e2b-8a1f-tok2',
    };
    expect(wallet.state.map((t) => t.id).toSet(), expectedIds);
    for (final t in wallet.state) {
      expect(t.bankSignature, isNot(kPlaceholderIssuerSig));
      expect(t.status, TokenStatus.inWallet);
    }
    final originalSignatures = {for (final t in wallet.state) t.id: t.bankSignature};
    expect(originalSignatures['backend-issued-b7e2b1b0-4a3d-4f1a-9c2e-tok1'], _issuerSig1);
    expect(originalSignatures['backend-issued-a441cabe-8d7c-4e2b-8a1f-tok2'], _issuerSig2);

    // ── Restart app ─────────────────────────────────────────────────────
    // A fresh notifier reading the same store must restore the EXACT
    // backend-issued tokens — same id, same real issuer signature.
    final restored = TokenWalletNotifier(_PoisonedTokenMinter(), store);
    await _tick();
    expect(restored.balance.paise, 25000);
    expect(restored.state.map((t) => t.id).toSet(), expectedIds);
    for (final t in restored.state) {
      expect(t.bankSignature, originalSignatures[t.id]);
    }

    // ── Offline payment ─────────────────────────────────────────────────
    // The restored, backend-issued tokens are what actually gets spent and
    // reaches the merchant — same tokenId, same issuer signature, plus a
    // real owner (device) signature over the transfer.
    final link = LinkedFakeTransport();
    final merchant = MerchantReceiveController(
      transport: link.peripheral,
      permissions: BlePermissionService(),
      merchantId: 'MER-BACKEND-INT',
    );
    await merchant.start(25000);
    await pump();
    final qr = parseMerchantQr(merchant.state.qrData);

    final customer = PaymentSessionController(
      transport: link.central,
      tokenWallet: restored,
      permissions: BlePermissionService(),
      deviceKeys: Ed25519DeviceKeyPairStore(FakeSecureStore()),
      params: PaymentSessionParams(
        merchantId: qr.merchantId,
        nonce: qr.nonce,
        amountPaise: qr.amountPaise!,
      ),
    );

    await customer.start();
    for (var i = 0; i < 40 && !customer.state.isTerminal; i++) {
      await pump(4);
    }

    expect(customer.state.status, PaymentSessionStatus.success);
    expect(restored.balance.paise, 0); // spent — atomicity point-of-no-return

    expect(merchant.state.status, MerchantReceiveStatus.received);
    expect(merchant.state.receivedTokens.map((t) => t.id).toSet(), expectedIds);
    for (final t in merchant.state.receivedTokens) {
      // Issuer signature survived storage + restart + BLE transfer unchanged
      // — this is the exact coin the backend minted, not a substitute.
      expect(t.bankSignature, originalSignatures[t.id]);
    }

    customer.dispose();
    merchant.dispose();
    link.dispose();
  });
}
