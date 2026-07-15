import 'package:flutter_test/flutter_test.dart';
import 'package:offline_wallet/data/token_store.dart';
import 'package:offline_wallet/domain/ble_message.dart';
import 'package:offline_wallet/domain/ble_transport.dart';
import 'package:offline_wallet/domain/transfer.dart';
import 'package:offline_wallet/features/pay/payment_session_controller.dart';
import 'package:offline_wallet/features/wallet/wallet_provider.dart';
import 'package:offline_wallet/platform/ble/ble_permission_service.dart';

import 'fake_ble_transports.dart';

const _params = PaymentSessionParams(merchantId: 'MER-1', nonce: 'n-1', amountPaise: 25000);

BleMessage _offer({String mid = 'MER-1', String nonce = 'n-1', int amount = 25000}) =>
    BleMessage.offer(PaymentOffer(amountPaise: amount, merchantId: mid, nonce: nonce, ts: 1));

void main() {
  late LinkedCentral central;
  late TokenWalletNotifier wallet;
  late PaymentSessionController controller;

  PaymentSessionController build({int mintPaise = 25000, PaymentSessionParams params = _params}) {
    wallet = TokenWalletNotifier(TokenMinter());
    if (mintPaise > 0) wallet.mint(mintPaise);
    controller = PaymentSessionController(
      transport: central,
      tokenWallet: wallet,
      permissions: BlePermissionService(),
      params: params,
    );
    return controller;
  }

  setUp(() => central = LinkedCentral());
  tearDown(() {
    controller.dispose();
    central.dispose();
  });

  test('ACK + TOKEN_TRANSFER sent on a valid OFFER, then success on COMPLETE', () async {
    build();
    await controller.start();
    await pump();
    expect(controller.state.status, PaymentSessionStatus.awaitingOffer);

    central.emitIncoming(_offer());
    await pump();

    // Customer accepted and sent tokens.
    expect(central.sent.map((m) => m.type),
        containsAllInOrder([BleMessageType.ack, BleMessageType.tokenTransfer]));
    expect(controller.state.status, PaymentSessionStatus.awaitingComplete);

    // The transfer carried exactly the selected tokens summing to the amount.
    final transferMsg = central.sent.firstWhere((m) => m.type == BleMessageType.tokenTransfer);
    final transfer = transferMsg.asTokenTransfer();
    expect(transfer.amountPaise, 25000);
    expect(transfer.tokens.length, 2); // ₹200 + ₹50

    // Merchant confirms → success, and tokens leave the wallet exactly now.
    central.emitIncoming(BleMessage.transferComplete(
        TransferComplete(nonce: 'n-1', receivedCount: transfer.tokens.length)));
    await pump();

    expect(controller.state.status, PaymentSessionStatus.success);
    expect(controller.state.tokenCount, 2);
    expect(wallet.balance.paise, 0); // spent
  });

  test('insufficient balance: empty wallet → CANCEL, failed, tokens retained', () async {
    build(mintPaise: 0);
    await controller.start();
    await pump();
    central.emitIncoming(_offer());
    await pump();

    expect(controller.state.status, PaymentSessionStatus.failed);
    expect(controller.state.reason, TransferRejectReason.insufficientBalance);
    expect(central.sent.any((m) => m.type == BleMessageType.cancel), isTrue);
    expect(wallet.balance.paise, 0);
  });

  test('nonce mismatch (QR↔OFFER binding) → failed, no tokens sent', () async {
    build();
    await controller.start();
    await pump();
    central.emitIncoming(_offer(nonce: 'WRONG'));
    await pump();

    expect(controller.state.status, PaymentSessionStatus.failed);
    expect(controller.state.reason, TransferRejectReason.nonceMismatch);
    expect(central.sent.any((m) => m.type == BleMessageType.tokenTransfer), isFalse);
    expect(wallet.balance.paise, 25000); // untouched
  });

  test('user cancel sends CANCEL and ends cancelled; tokens retained', () async {
    build();
    await controller.start();
    await pump();
    await controller.cancel();
    await pump();

    expect(controller.state.status, PaymentSessionStatus.cancelled);
    expect(central.sent.any((m) => m.type == BleMessageType.cancel), isTrue);
    expect(wallet.balance.paise, 25000);
  });

  test('merchant CANCEL → failed with reason, tokens retained', () async {
    build();
    await controller.start();
    await pump();
    central.emitIncoming(_offer());
    await pump(); // now awaitingComplete
    central.emitIncoming(BleMessage.cancel(const CancelNotice(TransferRejectReason.amountMismatch)));
    await pump();

    expect(controller.state.status, PaymentSessionStatus.failed);
    expect(controller.state.reason, TransferRejectReason.amountMismatch);
    expect(wallet.balance.paise, 25000); // never spent (no COMPLETE)
  });

  test('BLE disconnect mid-session → failed(disconnected), tokens retained', () async {
    build();
    await controller.start();
    await pump();
    expect(controller.state.status, PaymentSessionStatus.awaitingOffer);

    central.emitLink(BleLinkState.idle);
    await pump();

    expect(controller.state.status, PaymentSessionStatus.failed);
    expect(controller.state.reason, TransferRejectReason.disconnected);
    expect(wallet.balance.paise, 25000);
  });

  test('malformed inbound payload → failed(malformed)', () async {
    build();
    await controller.start();
    await pump();
    central.emitMalformed();
    await pump();

    expect(controller.state.status, PaymentSessionStatus.failed);
    expect(controller.state.reason, TransferRejectReason.malformed);
    expect(wallet.balance.paise, 25000);
  });
}
