import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_wallet/core/money.dart';
import 'package:offline_wallet/core/result.dart';
import 'package:offline_wallet/domain/token.dart';
import 'package:offline_wallet/domain/transfer.dart';

Money _money(int paise) => switch (Money.fromPaise(paise)) {
      Ok(:final value) => value,
      Err() => Money.zero(),
    };

Token _token(String id, int denomPaise) => Token(
      id: id,
      denomination: _money(denomPaise),
      ownerId: 'owner',
      issuedAt: DateTime.fromMillisecondsSinceEpoch(1752000000 * 1000),
      expiry: DateTime.fromMillisecondsSinceEpoch(1759776000 * 1000),
      status: TokenStatus.inWallet,
      bankSignature: 'issuer-sig-placeholder',
    );

void main() {
  test('Token JSON round-trips (denomination, dates, status, signature)', () {
    final token = _token('tok-1', 20000);
    final decoded = Token.fromJson(token.toJson());
    expect(decoded.id, token.id);
    expect(decoded.denomination.paise, 20000);
    expect(decoded.ownerId, 'owner');
    expect(decoded.status, TokenStatus.inWallet);
    expect(decoded.bankSignature, 'issuer-sig-placeholder');
    expect(decoded.issuedAt.millisecondsSinceEpoch, token.issuedAt.millisecondsSinceEpoch);
    expect(decoded.expiry.millisecondsSinceEpoch, token.expiry.millisecondsSinceEpoch);
  });

  test('TokenTransfer JSON round-trips with its tokens', () {
    final transfer = TokenTransfer(
      tokenIds: const ['tok-1', 'tok-2'],
      tokens: [_token('tok-1', 20000), _token('tok-2', 5000)],
      amountPaise: 25000,
      merchantId: 'MER-1',
      nonce: 'n-abc',
      timestamp: 1752403920,
      payerId: 'payer-1',
      payerPublicKey: 'aa' * 32,
      payerSignature: 'bb' * 64,
    );
    final decoded = TokenTransfer.fromJson(transfer.toJson());
    expect(decoded.tokenIds, ['tok-1', 'tok-2']);
    expect(decoded.tokens.length, 2);
    expect(decoded.tokens.first.denomination.paise, 20000);
    expect(decoded.amountPaise, 25000);
    expect(decoded.merchantId, 'MER-1');
    expect(decoded.nonce, 'n-abc');
    expect(decoded.payerId, 'payer-1');
    expect(decoded.payerPublicKey, 'aa' * 32);
    expect(decoded.payerSignature, 'bb' * 64);
  });

  test('PaymentOffer / TransferAck / TransferComplete / CancelNotice round-trip', () {
    final offer = PaymentOffer.fromJson(
        const PaymentOffer(amountPaise: 25000, merchantId: 'M', nonce: 'n', ts: 1).toJson());
    expect(offer.amountPaise, 25000);
    expect(offer.isOpenCash, isFalse);

    final ack = TransferAck.fromJson(const TransferAck(nonce: 'n').toJson());
    expect(ack.accepted, isTrue);

    final complete =
        TransferComplete.fromJson(const TransferComplete(nonce: 'n', receivedCount: 4).toJson());
    expect(complete.receivedCount, 4);

    final cancel =
        CancelNotice.fromJson(const CancelNotice(TransferRejectReason.cancelled).toJson());
    expect(cancel.reason, TransferRejectReason.cancelled);
  });

  test('TransferRejectReason wire values round-trip', () {
    for (final reason in TransferRejectReason.values) {
      expect(TransferRejectReason.fromWire(reason.wire), reason);
    }
  });

  test('Open Cash PaymentOffer omits "amount" from the wire JSON and round-trips to null', () {
    const offer = PaymentOffer(merchantId: 'M', nonce: 'n', ts: 1);
    expect(offer.isOpenCash, isTrue);

    final json = offer.toJson();
    expect(json.containsKey('amount'), isFalse);

    final decoded = PaymentOffer.fromJson(json);
    expect(decoded.amountPaise, isNull);
    expect(decoded.isOpenCash, isTrue);
    expect(decoded.merchantId, 'M');
    expect(decoded.nonce, 'n');
  });

  group('canonicalTransferPayload (owner-signed transfer, FR-PAY-04)', () {
    List<int> base({List<String>? tokenIds}) => canonicalTransferPayload(
          v: 1,
          tokenIds: tokenIds ?? const ['tok-1', 'tok-2'],
          amountPaise: 25000,
          merchantId: 'MER-1',
          nonce: 'n-abc',
          timestamp: 1752403920,
          payerId: 'payer-1',
          payerPublicKeyHex: 'aa' * 32,
        );

    test('is deterministic for the same fields', () {
      expect(base(), base());
    });

    test('is insensitive to tokenId order (sorted before signing)', () {
      expect(
        canonicalTransferPayload(
          v: 1,
          tokenIds: const ['tok-2', 'tok-1'],
          amountPaise: 25000,
          merchantId: 'MER-1',
          nonce: 'n-abc',
          timestamp: 1752403920,
          payerId: 'payer-1',
          payerPublicKeyHex: 'aa' * 32,
        ),
        base(),
      );
    });

    test('changes when any single field changes', () {
      final b = base();
      expect(
        canonicalTransferPayload(
          v: 1,
          tokenIds: const ['tok-1', 'tok-2'],
          amountPaise: 25001,
          merchantId: 'MER-1',
          nonce: 'n-abc',
          timestamp: 1752403920,
          payerId: 'payer-1',
          payerPublicKeyHex: 'aa' * 32,
        ),
        isNot(b),
      );
      expect(
        canonicalTransferPayload(
          v: 1,
          tokenIds: const ['tok-1', 'tok-2'],
          amountPaise: 25000,
          merchantId: 'MER-2', // different merchant
          nonce: 'n-abc',
          timestamp: 1752403920,
          payerId: 'payer-1',
          payerPublicKeyHex: 'aa' * 32,
        ),
        isNot(b),
      );
      expect(
        canonicalTransferPayload(
          v: 1,
          tokenIds: const ['tok-1', 'tok-2'],
          amountPaise: 25000,
          merchantId: 'MER-1',
          nonce: 'n-different',
          timestamp: 1752403920,
          payerId: 'payer-1',
          payerPublicKeyHex: 'aa' * 32,
        ),
        isNot(b),
      );
      expect(base(tokenIds: const ['tok-1', 'tok-3']), isNot(b));
      expect(
        canonicalTransferPayload(
          v: 1,
          tokenIds: const ['tok-1', 'tok-2'],
          amountPaise: 25000,
          merchantId: 'MER-1',
          nonce: 'n-abc',
          timestamp: 1752403920,
          payerId: 'payer-1',
          payerPublicKeyHex: 'bb' * 32, // substituted key
        ),
        isNot(b),
      );
    });

    test('safely escapes ids containing quotes/braces (no injection into the payload shape)', () {
      final tricky = canonicalTransferPayload(
        v: 1,
        tokenIds: const ['"}{"merchantId":"evil'],
        amountPaise: 1,
        merchantId: 'M',
        nonce: 'n',
        timestamp: 1,
        payerId: 'p',
        payerPublicKeyHex: 'aa' * 32,
      );
      final parsed = jsonDecode(utf8.decode(tricky)) as Map<String, dynamic>;
      expect((parsed['tokenIds'] as List).single, '"}{"merchantId":"evil');
      expect(parsed['merchantId'], 'M');
    });
  });
}
