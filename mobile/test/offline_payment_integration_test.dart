import 'package:flutter_test/flutter_test.dart';
import 'package:offline_wallet/data/token_store.dart';
import 'package:offline_wallet/domain/qr_codec.dart';
import 'package:offline_wallet/features/pay/payment_session_controller.dart';
import 'package:offline_wallet/features/receive/merchant_receive_controller.dart';
import 'package:offline_wallet/features/wallet/wallet_provider.dart';
import 'package:offline_wallet/platform/ble/ble_permission_service.dart';

import 'fake_ble_transports.dart';

/// End-to-end offline payment over a wired in-memory BLE link: a real customer
/// PaymentSessionController and a real MerchantReceiveController exchange the
/// full OFFER → ACK → TOKEN_TRANSFER → TRANSFER_COMPLETE sequence. This is the
/// protocol proof that can't be done with a single physical phone.
void main() {
  test('full offline payment: customer pays ₹250, both balances update', () async {
    final link = LinkedFakeTransport();

    // Merchant requests ₹250, advertises, and shows a QR.
    final merchant = MerchantReceiveController(
      transport: link.peripheral,
      permissions: BlePermissionService(),
      merchantId: 'MER-INT',
    );
    await merchant.start(25000);
    await pump();

    // Customer "scans" the merchant's QR to learn merchantId + nonce + amount.
    final qr = parseMerchantQr(merchant.state.qrData);

    // Customer wallet holds ₹250 of minted offline cash.
    final wallet = TokenWalletNotifier(TokenMinter())..mint(25000);
    expect(wallet.balance.paise, 25000);

    final customer = PaymentSessionController(
      transport: link.central,
      tokenWallet: wallet,
      permissions: BlePermissionService(),
      params: PaymentSessionParams(
        merchantId: qr.merchantId,
        nonce: qr.nonce,
        amountPaise: qr.amountPaise!,
      ),
    );

    await customer.start();
    // Let the OFFER → ACK → TOKEN_TRANSFER → COMPLETE chain settle.
    for (var i = 0; i < 40 && !customer.state.isTerminal; i++) {
      await pump(4);
    }

    // Customer: paid, tokens gone.
    expect(customer.state.status, PaymentSessionStatus.success);
    expect(customer.state.tokenCount, 2); // ₹200 + ₹50
    expect(wallet.balance.paise, 0);

    // Merchant: received the tokens as Pending Settlement.
    expect(merchant.state.status, MerchantReceiveStatus.received);
    expect(merchant.state.receivedCount, 2);
    expect(merchant.state.pendingSettlement.paise, 25000);

    // Money-supply invariant: no value created or destroyed in the transfer.
    expect(wallet.balance.paise + merchant.state.pendingSettlement.paise, 25000);

    customer.dispose();
    merchant.dispose();
    link.dispose();
  });
}
