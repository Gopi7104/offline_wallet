import 'package:flutter_test/flutter_test.dart';
import 'package:offline_wallet/data/token_store.dart';
import 'package:offline_wallet/domain/ble_message.dart';
import 'package:offline_wallet/domain/token.dart';
import 'package:offline_wallet/domain/transfer.dart';
import 'package:offline_wallet/features/receive/merchant_receive_controller.dart';
import 'package:offline_wallet/platform/ble/ble_permission_service.dart';

import 'fake_ble_transports.dart';

const _mid = 'MER-X';

void main() {
  late LinkedPeripheral peripheral;
  late MerchantReceiveController controller;

  List<Token> tokensFor(int amountPaise) => TokenMinter().mint(amountPaise, ownerId: 'payer-1');

  TokenTransfer transferFor(String nonce, List<Token> tokens, {int? amountOverride}) => TokenTransfer(
        tokenIds: tokens.map((t) => t.id).toList(),
        tokens: tokens,
        amountPaise: amountOverride ?? tokens.fold(0, (a, t) => a + t.denomination.paise),
        merchantId: _mid,
        nonce: nonce,
        timestamp: 1752403920,
        payerId: 'payer-1',
        payerSignature: 'payer-sig-placeholder',
      );

  setUp(() {
    peripheral = LinkedPeripheral();
    controller = MerchantReceiveController(
      transport: peripheral,
      permissions: BlePermissionService(),
      merchantId: _mid,
    );
  });
  tearDown(() {
    controller.dispose();
    peripheral.dispose();
  });

  Future<String> startAndGetNonce(int amountPaise) async {
    await controller.start(amountPaise);
    await pump();
    peripheral.emitConnected('payer-1');
    await pump();
    final offer = peripheral.sent.firstWhere((m) => m.type == BleMessageType.offer);
    return offer.asOffer().nonce;
  }

  test('sends OFFER when a customer connects', () async {
    final nonce = await startAndGetNonce(25000);
    final offer = peripheral.sent.firstWhere((m) => m.type == BleMessageType.offer).asOffer();
    expect(offer.merchantId, _mid);
    expect(offer.amountPaise, 25000);
    expect(offer.nonce, nonce);
  });

  test('does NOT send OFFER before the customer-ready signal', () async {
    // Regression for the OFFER-before-subscribe race: after advertising starts,
    // the merchant must stay silent until `connectedDeviceId` fires. On real
    // hardware that signal is the central's notification-subscribe (an OFFER
    // pushed before it is dropped by the BLE stack, with no retransmission).
    await controller.start(25000);
    await pump();
    expect(controller.state.status, MerchantReceiveStatus.waiting);
    expect(peripheral.sent.any((m) => m.type == BleMessageType.offer), isFalse);

    // Only once the customer is connected + subscribed does the OFFER go out.
    peripheral.emitConnected('payer-1');
    await pump();
    expect(peripheral.sent.where((m) => m.type == BleMessageType.offer).length, 1);
  });

  test('receives tokens: stores them, credits Pending Settlement, sends COMPLETE', () async {
    final nonce = await startAndGetNonce(25000);

    peripheral.emitIncoming(BleMessage.ack(TransferAck(nonce: nonce)));
    await pump();
    expect(controller.state.status, MerchantReceiveStatus.receiving);

    final tokens = tokensFor(25000);
    peripheral.emitIncoming(BleMessage.tokenTransfer(transferFor(nonce, tokens)));
    await pump();

    expect(controller.state.status, MerchantReceiveStatus.received);
    expect(controller.state.receivedCount, tokens.length);
    expect(controller.state.pendingSettlement.paise, 25000);
    expect(peripheral.sent.any((m) => m.type == BleMessageType.transferComplete), isTrue);
  });

  test('duplicate transfer for the same nonce → resend COMPLETE, no double-credit', () async {
    final nonce = await startAndGetNonce(25000);
    final tokens = tokensFor(25000);

    peripheral.emitIncoming(BleMessage.tokenTransfer(transferFor(nonce, tokens)));
    await pump();
    final completesAfterFirst =
        peripheral.sent.where((m) => m.type == BleMessageType.transferComplete).length;
    expect(controller.state.receivedCount, tokens.length);

    // Re-send the same transfer (e.g. a retried BLE connection).
    peripheral.emitIncoming(BleMessage.tokenTransfer(transferFor(nonce, tokens)));
    await pump();

    expect(controller.state.receivedCount, tokens.length); // NOT doubled
    expect(controller.state.pendingSettlement.paise, 25000); // NOT doubled
    final completesAfterDup =
        peripheral.sent.where((m) => m.type == BleMessageType.transferComplete).length;
    expect(completesAfterDup, completesAfterFirst + 1); // idempotent re-ack
  });

  test('amount mismatch → CANCEL(amountMismatch), rejected', () async {
    final nonce = await startAndGetNonce(25000);
    // Tokens sum to ₹200 but merchant requested ₹250.
    final tokens = tokensFor(20000);
    peripheral.emitIncoming(BleMessage.tokenTransfer(transferFor(nonce, tokens)));
    await pump();

    expect(controller.state.status, MerchantReceiveStatus.rejected);
    expect(controller.state.reason, TransferRejectReason.amountMismatch);
    final cancel = peripheral.sent.firstWhere((m) => m.type == BleMessageType.cancel);
    expect(cancel.asCancel().reason, TransferRejectReason.amountMismatch);
    expect(controller.state.receivedCount, 0);
  });

  test('nonce mismatch → CANCEL(nonceMismatch), rejected', () async {
    await startAndGetNonce(25000);
    final tokens = tokensFor(25000);
    peripheral.emitIncoming(BleMessage.tokenTransfer(transferFor('WRONG-NONCE', tokens)));
    await pump();

    expect(controller.state.status, MerchantReceiveStatus.rejected);
    expect(controller.state.reason, TransferRejectReason.nonceMismatch);
  });

  test('malformed inbound payload → CANCEL(malformed), rejected', () async {
    await startAndGetNonce(25000);
    peripheral.emitMalformed();
    await pump();

    expect(controller.state.status, MerchantReceiveStatus.rejected);
    expect(controller.state.reason, TransferRejectReason.malformed);
  });

  test('customer CANCEL → cancelled', () async {
    await startAndGetNonce(25000);
    peripheral.emitIncoming(BleMessage.cancel(const CancelNotice(TransferRejectReason.cancelled)));
    await pump();

    expect(controller.state.status, MerchantReceiveStatus.cancelled);
  });
}
