import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_wallet/domain/merchant.dart';
import 'package:offline_wallet/domain/qr_codec.dart';

/// Builds a raw scanned-QR string: compact JSON (§5) → base64url.
String validQr({
  int v = 1,
  String typ = 'offer-req',
  String mid = 'MER-ABC123DEF456',
  String nonce = 'nonce-1',
  int? ts,
  int? amt,
}) {
  final json = jsonEncode({
    'v': v,
    'typ': typ,
    'mid': mid,
    'n': nonce,
    'ts': ts ?? 1752480000,
    if (amt != null) 'amt': amt,
  });
  return base64Url.encode(utf8.encode(json)).replaceAll('=', '');
}

void main() {
  group('parseMerchantQr — valid', () {
    test('parses a well-formed payload', () {
      final p = parseMerchantQr(validQr());
      expect(p.v, 1);
      expect(p.typ, 'offer-req');
      expect(p.merchantId, 'MER-ABC123DEF456');
      expect(p.nonce, 'nonce-1');
      expect(p.ts, 1752480000);
      expect(p.amountPaise, isNull);
    });

    test('parses the optional amount when present', () {
      final p = parseMerchantQr(validQr(amt: 25000));
      expect(p.amountPaise, 25000);
    });

    test('tolerates surrounding whitespace', () {
      final p = parseMerchantQr('   ${validQr()}  ');
      expect(p.merchantId, 'MER-ABC123DEF456');
    });
  });

  group('parseMerchantQr — rejects', () {
    void expectReject(String raw, {String? messageContains}) {
      expect(
        () => parseMerchantQr(raw),
        throwsA(isA<QrFormatException>()),
      );
      if (messageContains != null) {
        try {
          parseMerchantQr(raw);
        } on QrFormatException catch (e) {
          expect(e.message.toLowerCase(), contains(messageContains.toLowerCase()));
        }
      }
    }

    String encode(Map<String, dynamic> json) =>
        base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

    test('empty string', () => expectReject('', messageContains: 'empty'));
    test('non-base64/JSON garbage', () => expectReject('not-a-qr!!!', messageContains: 'not a valid'));
    test('JSON array (not object)',
        () => expectReject(base64Url.encode(utf8.encode('[1,2,3]')).replaceAll('=', ''), messageContains: 'not a valid'));
    test('missing version', () => expectReject(encode({'typ': 'offer-req', 'mid': 'MER-1', 'n': 'n', 'ts': 1752480000}), messageContains: 'not a payment'));
    test('unsupported version', () => expectReject(validQr(v: 2), messageContains: 'unsupported'));
    test('wrong message type', () => expectReject(validQr(typ: 'ack'), messageContains: 'not a payment offer'));
    test('missing merchantId', () => expectReject(encode({'v': 1, 'typ': 'offer-req', 'n': 'n', 'ts': 1752480000}), messageContains: 'merchant'));
    test('empty merchantId', () => expectReject(validQr(mid: '   '), messageContains: 'merchant'));
    test('missing nonce', () => expectReject(encode({'v': 1, 'typ': 'offer-req', 'mid': 'MER-1', 'ts': 1752480000}), messageContains: 'nonce'));
    test('bad timestamp (non-epoch string)', () => expectReject(encode({'v': 1, 'typ': 'offer-req', 'mid': 'MER-1', 'n': 'n', 'ts': 'not-a-date'}), messageContains: 'timestamp'));
    test('negative amount', () => expectReject(validQr(amt: -1), messageContains: 'amount'));
  });

  group('encodeMerchantQr — round-trips with the parser', () {
    test('encode then parse yields the same fields', () {
      const original = QrPayload(
        v: 1,
        merchantId: 'MER-5CCE3BF59C3C',
        nonce: 'abc-123',
        ts: 1752490000,
        amountPaise: 50000,
      );
      final parsed = parseMerchantQr(encodeMerchantQr(original));
      expect(parsed.v, original.v);
      expect(parsed.typ, original.typ);
      expect(parsed.merchantId, original.merchantId);
      expect(parsed.nonce, original.nonce);
      expect(parsed.ts, original.ts);
      expect(parsed.amountPaise, original.amountPaise);
    });
  });
}
