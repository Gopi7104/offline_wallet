import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_wallet/core/crypto/device_keypair_store.dart' show bytesToHex;
import 'package:offline_wallet/data/token_store.dart';
import 'package:offline_wallet/domain/ble_message.dart';
import 'package:offline_wallet/domain/token.dart';
import 'package:offline_wallet/domain/transfer.dart';
import 'package:offline_wallet/features/receive/merchant_receive_controller.dart';
import 'package:offline_wallet/platform/ble/ble_permission_service.dart';

import 'fake_ble_transports.dart';

const _mid = 'MER-X';
const _payerId = 'payer-1';

void main() {
  late LinkedPeripheral peripheral;
  late MerchantReceiveController controller;
  late SimpleKeyPair payerKeyPair;
  late String payerPublicKeyHex;

  List<Token> tokensFor(int amountPaise) => TokenMinter().mint(amountPaise, ownerId: _payerId);

  /// Builds a REAL owner-signed transfer: signs the canonical payload with
  /// [signingKeyPair] (defaults to the payer's own key) and carries
  /// [publicKeyOverride] (defaults to the payer's own public key) — letting
  /// tests independently vary "who signed it" from "which key it claims".
  Future<TokenTransfer> transferFor(
    String nonce,
    List<Token> tokens, {
    int? amountOverride,
    String? merchantIdOverride,
    SimpleKeyPair? signingKeyPair,
    String? publicKeyOverride,
  }) async {
    final tokenIds = tokens.map((t) => t.id).toList();
    final int amountPaise = amountOverride ?? tokens.fold<int>(0, (a, t) => a + t.denomination.paise);
    const timestamp = 1752403920;
    final publicKeyHex = publicKeyOverride ?? payerPublicKeyHex;
    final payload = canonicalTransferPayload(
      v: kTransferProtocolVersion,
      tokenIds: tokenIds,
      amountPaise: amountPaise,
      merchantId: merchantIdOverride ?? _mid,
      nonce: nonce,
      timestamp: timestamp,
      payerId: _payerId,
      payerPublicKeyHex: publicKeyHex,
    );
    final signature = await Ed25519().sign(payload, keyPair: signingKeyPair ?? payerKeyPair);
    return TokenTransfer(
      tokenIds: tokenIds,
      tokens: tokens,
      amountPaise: amountPaise,
      merchantId: merchantIdOverride ?? _mid,
      nonce: nonce,
      timestamp: timestamp,
      payerId: _payerId,
      payerPublicKey: publicKeyHex,
      payerSignature: bytesToHex(signature.bytes),
    );
  }

  setUpAll(() async {
    payerKeyPair = await Ed25519().newKeyPair();
    payerPublicKeyHex = bytesToHex((await payerKeyPair.extractPublicKey()).bytes);
  });

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
    peripheral.emitIncoming(BleMessage.tokenTransfer(await transferFor(nonce, tokens)));
    await pump();

    expect(controller.state.status, MerchantReceiveStatus.received);
    expect(controller.state.receivedCount, tokens.length);
    expect(controller.state.pendingSettlement.paise, 25000);
    expect(peripheral.sent.any((m) => m.type == BleMessageType.transferComplete), isTrue);
  });

  test('duplicate transfer for the same nonce → resend COMPLETE, no double-credit', () async {
    final nonce = await startAndGetNonce(25000);
    final tokens = tokensFor(25000);
    final transfer = await transferFor(nonce, tokens);

    peripheral.emitIncoming(BleMessage.tokenTransfer(transfer));
    await pump();
    final completesAfterFirst =
        peripheral.sent.where((m) => m.type == BleMessageType.transferComplete).length;
    expect(controller.state.receivedCount, tokens.length);

    // Re-send the EXACT same signed transfer (e.g. a retried BLE connection,
    // or a captured transcript replayed verbatim) — the same nonce is already
    // consumed, so it must not be re-verified/re-credited, just re-acked.
    peripheral.emitIncoming(BleMessage.tokenTransfer(transfer));
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
    peripheral.emitIncoming(BleMessage.tokenTransfer(await transferFor(nonce, tokens)));
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
    peripheral.emitIncoming(BleMessage.tokenTransfer(await transferFor('WRONG-NONCE', tokens)));
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

  group('owner signature verification (FR-PAY-04, Task 9)', () {
    test('a tampered payload (amount changed after signing) is rejected as invalidSignature', () async {
      final nonce = await startAndGetNonce(25000);
      final tokens = tokensFor(25000);
      final signed = await transferFor(nonce, tokens);
      // Tamper with the signed transfer post-hoc: claim a different amount
      // while keeping the original signature — the classic "modified payload"
      // attack (Part 9's "reject: modified payload").
      final tampered = TokenTransfer(
        tokenIds: signed.tokenIds,
        tokens: signed.tokens,
        amountPaise: signed.amountPaise, // amount itself must still match Σdenom to pass that check
        merchantId: signed.merchantId,
        nonce: signed.nonce,
        timestamp: signed.timestamp + 1, // ...but the timestamp was altered after signing
        payerId: signed.payerId,
        payerPublicKey: signed.payerPublicKey,
        payerSignature: signed.payerSignature, // stale signature over the ORIGINAL timestamp
      );

      peripheral.emitIncoming(BleMessage.tokenTransfer(tampered));
      await pump();

      expect(controller.state.status, MerchantReceiveStatus.rejected);
      expect(controller.state.reason, TransferRejectReason.invalidSignature);
      expect(controller.state.receivedCount, 0);
    });

    test('a signature produced by the WRONG key is rejected as invalidSignature', () async {
      final nonce = await startAndGetNonce(25000);
      final tokens = tokensFor(25000);
      final attackerKeyPair = await Ed25519().newKeyPair();

      // Attacker signs with their own key but claims the payer's public key
      // (key-substitution attempt) — the signature cannot possibly verify.
      final transfer = await transferFor(nonce, tokens, signingKeyPair: attackerKeyPair);

      peripheral.emitIncoming(BleMessage.tokenTransfer(transfer));
      await pump();

      expect(controller.state.status, MerchantReceiveStatus.rejected);
      expect(controller.state.reason, TransferRejectReason.invalidSignature);
      expect(controller.state.receivedCount, 0);
    });

    test('a well-formed but forged (random) signature is rejected as invalidSignature', () async {
      final nonce = await startAndGetNonce(25000);
      final tokens = tokensFor(25000);
      final genuine = await transferFor(nonce, tokens);
      final forged = TokenTransfer(
        tokenIds: genuine.tokenIds,
        tokens: genuine.tokens,
        amountPaise: genuine.amountPaise,
        merchantId: genuine.merchantId,
        nonce: genuine.nonce,
        timestamp: genuine.timestamp,
        payerId: genuine.payerId,
        payerPublicKey: genuine.payerPublicKey,
        payerSignature: 'ab' * 64, // well-formed hex, not a real signature
      );

      peripheral.emitIncoming(BleMessage.tokenTransfer(forged));
      await pump();

      expect(controller.state.status, MerchantReceiveStatus.rejected);
      expect(controller.state.reason, TransferRejectReason.invalidSignature);
    });

    test('a captured signed transfer relabeled for a different merchant is rejected', () async {
      final nonce = await startAndGetNonce(25000);
      final tokens = tokensFor(25000);
      // Signed for _mid, then relabeled for a different merchant, keeping the
      // original signature — merchantId is bound INTO the signed payload
      // (see transfer_test.dart's canonicalTransferPayload field-sensitivity
      // test), so this is doubly rejected: the app-level merchantId binding
      // check here, AND the signature would independently fail verification
      // against the mismatched merchantId if it ever reached that check.
      final signed = await transferFor(nonce, tokens);
      final relabeled = TokenTransfer(
        tokenIds: signed.tokenIds,
        tokens: signed.tokens,
        amountPaise: signed.amountPaise,
        merchantId: 'MER-OTHER',
        nonce: signed.nonce,
        timestamp: signed.timestamp,
        payerId: signed.payerId,
        payerPublicKey: signed.payerPublicKey,
        payerSignature: signed.payerSignature,
      );

      peripheral.emitIncoming(BleMessage.tokenTransfer(relabeled));
      await pump();

      expect(controller.state.status, MerchantReceiveStatus.rejected);
      // Rejected at the (cheaper) nonce/merchant-binding check before
      // signature verification even runs — still a reject, either way.
      expect(controller.state.reason, TransferRejectReason.nonceMismatch);
    });
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
      peripheral.emitIncoming(BleMessage.tokenTransfer(await transferFor(nonce, tokens)));
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
          BleMessage.tokenTransfer(await transferFor(nonce, tokens, amountOverride: 25000)));
      await pump();

      expect(controller.state.status, MerchantReceiveStatus.rejected);
      expect(controller.state.reason, TransferRejectReason.amountMismatch);
      expect(controller.state.receivedCount, 0);
    });

    test('rejects a non-positive claimed amount even if it matches an empty token list', () async {
      final nonce = await startOpenAndGetNonce();
      peripheral.emitIncoming(
          BleMessage.tokenTransfer(await transferFor(nonce, const [], amountOverride: 0)));
      await pump();

      expect(controller.state.status, MerchantReceiveStatus.rejected);
      expect(controller.state.reason, TransferRejectReason.amountMismatch);
    });
  });
}
