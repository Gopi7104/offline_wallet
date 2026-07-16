import 'dart:convert';
import 'merchant.dart';

/// Thrown when a scanned QR is not a valid/supported merchant payment QR.
/// The [message] is user-friendly and safe to show directly.
class QrFormatException implements Exception {
  final String message;
  QrFormatException(this.message);
  @override
  String toString() => message;
}

/// Supported merchant-QR payload version and message type.
/// Matches PAYMENT_PROTOCOL.md §5 exactly.
const int kSupportedQrVersion = 1;
const String kOfferReqType = 'offer-req';

/// Encode a merchant QR payload into the string a QR image carries.
///
/// PAYMENT_PROTOCOL.md §5: compact JSON keys (`v/typ/mid/n/ts/amt`), epoch
/// seconds, then base64url — with no secret material.
String encodeMerchantQr(QrPayload p) {
  final json = <String, dynamic>{
    'v': p.v,
    'typ': p.typ,
    'mid': p.merchantId,
    'n': p.nonce,
    'ts': p.ts,
    if (p.amountPaise != null) 'amt': p.amountPaise,
  };
  return base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
}

/// Parse + validate a scanned merchant QR string into a [QrPayload].
///
/// Throws [QrFormatException] with a friendly message for any malformed or
/// unsupported input. Expects the base64url(JSON) envelope from §5: version,
/// message type, merchant id, nonce, timestamp (and the optional amount).
QrPayload parseMerchantQr(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    throw QrFormatException('Empty QR code.');
  }

  final Object? decoded;
  try {
    final jsonString = utf8.decode(base64Url.decode(_padBase64Url(trimmed)));
    decoded = jsonDecode(jsonString);
  } catch (_) {
    throw QrFormatException('This QR code is not a valid payment code.');
  }
  if (decoded is! Map<String, dynamic>) {
    throw QrFormatException('This QR code is not a valid payment code.');
  }

  // version
  final version = decoded['v'];
  if (version is! int) {
    throw QrFormatException('This is not a payment QR code.');
  }
  if (version != kSupportedQrVersion) {
    throw QrFormatException('Unsupported QR version ($version). Please update the app.');
  }

  // message type
  final typ = decoded['typ'];
  if (typ is! String || typ != kOfferReqType) {
    throw QrFormatException('This QR code is not a payment offer.');
  }

  // merchant id
  final merchantId = decoded['mid'];
  if (merchantId is! String || merchantId.trim().isEmpty) {
    throw QrFormatException('This QR code is missing a merchant.');
  }

  // nonce
  final nonce = decoded['n'];
  if (nonce is! String || nonce.trim().isEmpty) {
    throw QrFormatException('This QR code is missing its security nonce.');
  }

  // timestamp (epoch seconds)
  final ts = decoded['ts'];
  if (ts is! int) {
    throw QrFormatException('This QR code has an invalid timestamp.');
  }

  // optional requested amount
  int? amountPaise;
  final amt = decoded['amt'];
  if (amt != null) {
    if (amt is! int || amt < 0) {
      throw QrFormatException('This QR code has an invalid amount.');
    }
    amountPaise = amt;
  }

  return QrPayload(
    v: version,
    typ: typ,
    merchantId: merchantId,
    nonce: nonce,
    ts: ts,
    amountPaise: amountPaise,
  );
}

/// base64Url.decode requires length%4==0 padding; QR/JSON producers commonly
/// omit it (per §3), so restore it before decoding.
String _padBase64Url(String input) {
  final remainder = input.length % 4;
  if (remainder == 0) return input;
  return input + '=' * (4 - remainder);
}
