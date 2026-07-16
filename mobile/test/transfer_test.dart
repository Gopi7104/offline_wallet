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
      payerSignature: 'payer-sig-placeholder',
    );
    final decoded = TokenTransfer.fromJson(transfer.toJson());
    expect(decoded.tokenIds, ['tok-1', 'tok-2']);
    expect(decoded.tokens.length, 2);
    expect(decoded.tokens.first.denomination.paise, 20000);
    expect(decoded.amountPaise, 25000);
    expect(decoded.merchantId, 'MER-1');
    expect(decoded.nonce, 'n-abc');
    expect(decoded.payerId, 'payer-1');
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
}
