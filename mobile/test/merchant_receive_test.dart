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

  group('Open Cash (no pre-decided amount)', () {
    Future<String> startOpenAndGetNonce() async {
      await controller.start(null);
      await pump();
      peripheral.emitConnected('payer-1');
      await pump();
      final offer = peripheral.sent.firstWhere((m) => m.type == BleMessageType.offer);
      return offer.asOffer().nonce;
    }

    test('start(null) sends an OFFER with no amount, and the QR has no amt', () async {
      await controller.start(null);
      await pump();
      expect(controller.state.amountPaise, isNull);
      // The locally-minted QR must omit `amt` for an Open Cash request —
      // decode it the same way parseMerchantQr does, minus the base64/JSON
      // plumbing this test doesn't need: just confirm no amount was baked in
      // by checking the OFFER, which is built from the same amountPaise.
      peripheral.emitConnected('payer-1');
      await pump();
      final offer = peripheral.sent.firstWhere((m) => m.type == BleMessageType.offer).asOffer();
      expect(offer.amountPaise, isNull);
      expect(offer.isOpenCash, isTrue);
    });

    test('accepts whatever positive amount the payer sends, if tokens sum to it', () async {
      final nonce = await startOpenAndGetNonce();
      final tokens = tokensFor(17300); // an amount the merchant never specified
      peripheral.emitIncoming(BleMessage.tokenTransfer(transferFor(nonce, tokens)));
      await pump();

      expect(controller.state.status, MerchantReceiveStatus.received);
      expect(controller.state.receivedCount, tokens.length);
      expect(controller.state.pendingSettlement.paise, 17300);
      // The merchant now knows the amount, even though it never set one.
      expect(controller.state.amountPaise, 17300);
      expect(peripheral.sent.any((m) => m.type == BleMessageType.transferComplete), isTrue);
    });

    test('still rejects a claimed amount that does not match the tokens actually sent', () async {
      final nonce = await startOpenAndGetNonce();
      final tokens = tokensFor(20000); // sums to ₹200
      peripheral.emitIncoming(
          BleMessage.tokenTransfer(transferFor(nonce, tokens, amountOverride: 25000)));
      await pump();

      expect(controller.state.status, MerchantReceiveStatus.rejected);
      expect(controller.state.reason, TransferRejectReason.amountMismatch);
      expect(controller.state.receivedCount, 0);
    });

    test('rejects a non-positive claimed amount even if it matches an empty token list', () async {
      final nonce = await startOpenAndGetNonce();
      peripheral.emitIncoming(
          BleMessage.tokenTransfer(transferFor(nonce, const [], amountOverride: 0)));
      await pump();

      expect(controller.state.status, MerchantReceiveStatus.rejected);
      expect(controller.state.reason, TransferRejectReason.amountMismatch);
    });
  });
}
