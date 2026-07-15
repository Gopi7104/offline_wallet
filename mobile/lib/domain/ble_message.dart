import 'dart:convert';

import 'transfer.dart';

/// Thrown when bytes received over the BLE characteristic aren't a valid
/// [BleMessage]. Mirrors [QrFormatException] in `domain/qr_codec.dart`.
class BleMessageFormatException implements Exception {
  final String message;
  BleMessageFormatException(this.message);
  @override
  String toString() => message;
}

/// The real offline-payment protocol messages (Task 8), replacing Task 7's
/// PING/PONG/HELLO/READY placeholders. One BLE service, one characteristic;
/// each message is a JSON object multiplexed by [type] (see PAYMENT_PROTOCOL.md
/// §6.1 — we collapse its OFFER/ACK/CTRL characteristics onto a single
/// characteristic and distinguish by type):
///   OFFER            merchant → payer: the authoritative payment request
///   ACK              payer → merchant: "I accept, tokens follow"
///   TOKEN_TRANSFER   payer → merchant: transfer proof + the tokens
///   TRANSFER_COMPLETE merchant → payer: validated + stored (success)
///   CANCEL           either → other: abort with a reason (no value moves)
enum BleMessageType {
  offer,
  ack,
  tokenTransfer,
  transferComplete,
  cancel;

  /// Wire encoding: SCREAMING_SNAKE_CASE (`tokenTransfer` → `TOKEN_TRANSFER`).
  String get wireValue {
    switch (this) {
      case BleMessageType.offer:
        return 'OFFER';
      case BleMessageType.ack:
        return 'ACK';
      case BleMessageType.tokenTransfer:
        return 'TOKEN_TRANSFER';
      case BleMessageType.transferComplete:
        return 'TRANSFER_COMPLETE';
      case BleMessageType.cancel:
        return 'CANCEL';
    }
  }

  static BleMessageType fromWireValue(String value) {
    for (final type in BleMessageType.values) {
      if (type.wireValue == value) return type;
    }
    throw BleMessageFormatException('Unknown BLE message type "$value".');
  }
}

/// A single JSON UTF-8 protocol message: a [type] plus a type-specific [body]
/// object, e.g. `{"type":"OFFER","body":{"v":1,"amount":25000,...}}`.
class BleMessage {
  final BleMessageType type;
  final Map<String, dynamic> body;

  const BleMessage({required this.type, this.body = const {}});

  // --- typed constructors -------------------------------------------------
  factory BleMessage.offer(PaymentOffer offer) =>
      BleMessage(type: BleMessageType.offer, body: offer.toJson());

  factory BleMessage.ack(TransferAck ack) =>
      BleMessage(type: BleMessageType.ack, body: ack.toJson());

  factory BleMessage.tokenTransfer(TokenTransfer transfer) =>
      BleMessage(type: BleMessageType.tokenTransfer, body: transfer.toJson());

  factory BleMessage.transferComplete(TransferComplete complete) =>
      BleMessage(type: BleMessageType.transferComplete, body: complete.toJson());

  factory BleMessage.cancel(CancelNotice cancel) =>
      BleMessage(type: BleMessageType.cancel, body: cancel.toJson());

  // --- typed accessors (throw BleMessageFormatException on shape mismatch) --
  PaymentOffer asOffer() => _parse(BleMessageType.offer, PaymentOffer.fromJson);
  TransferAck asAck() => _parse(BleMessageType.ack, TransferAck.fromJson);
  TokenTransfer asTokenTransfer() =>
      _parse(BleMessageType.tokenTransfer, TokenTransfer.fromJson);
  TransferComplete asTransferComplete() =>
      _parse(BleMessageType.transferComplete, TransferComplete.fromJson);
  CancelNotice asCancel() => _parse(BleMessageType.cancel, CancelNotice.fromJson);

  T _parse<T>(BleMessageType expected, T Function(Map<String, dynamic>) fromJson) {
    if (type != expected) {
      throw BleMessageFormatException(
        'Expected ${expected.wireValue} but got ${type.wireValue}.',
      );
    }
    try {
      return fromJson(body);
    } catch (e) {
      throw BleMessageFormatException('Malformed ${type.wireValue} body: $e');
    }
  }

  // --- serialization ------------------------------------------------------
  Map<String, dynamic> toJson() => {'type': type.wireValue, 'body': body};

  String encode() => jsonEncode(toJson());

  static BleMessage fromJson(Map<String, dynamic> json) {
    final rawType = json['type'];
    if (rawType is! String) {
      throw BleMessageFormatException('BLE message is missing "type".');
    }
    final rawBody = json['body'];
    if (rawBody != null && rawBody is! Map) {
      throw BleMessageFormatException('BLE message "body" must be an object.');
    }
    return BleMessage(
      type: BleMessageType.fromWireValue(rawType),
      body: rawBody == null ? const {} : (rawBody as Map).cast<String, dynamic>(),
    );
  }

  static BleMessage decode(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw BleMessageFormatException('BLE payload is not valid JSON.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw BleMessageFormatException('BLE payload is not a JSON object.');
    }
    return fromJson(decoded);
  }

  @override
  String toString() => 'BleMessage(${type.wireValue})';
}
