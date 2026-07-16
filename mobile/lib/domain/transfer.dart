import 'token.dart';

/// Protocol version for the offline payment exchange (PAYMENT_PROTOCOL.md §10).
const int kTransferProtocolVersion = 1;

/// Transfer validity window (§10): a Transfer older than this is stale.
const Duration kTransferValidity = Duration(seconds: 120);

/// Max tokens (coins) carried in one BLE transfer (§10).
const int kMaxTokensPerTransfer = 64;

/// Why a transfer was rejected/aborted. A subset of PAYMENT_PROTOCOL.md §7
/// reject reasons plus the transport aborts the task calls out. Carried in a
/// CANCEL notice (and surfaced to the user).
enum TransferRejectReason {
  insufficientBalance,
  insufficientTokens,
  amountMismatch,
  nonceMismatch,
  expiredToken,
  malformed,
  duplicate,
  cancelled,
  disconnected,
  internal;

  String get wire => name;

  static TransferRejectReason fromWire(String value) =>
      TransferRejectReason.values.firstWhere(
        (r) => r.name == value,
        orElse: () => TransferRejectReason.internal,
      );

  /// User-facing sentence for a Material dialog.
  String get message => switch (this) {
    insufficientBalance => 'You do not have enough offline cash for this payment.',
    insufficientTokens =>
      'Your offline cash cannot make this exact amount. Load more to continue.',
    amountMismatch => 'The tokens sent did not match the requested amount.',
    nonceMismatch => 'This payment request did not match. Please rescan the QR.',
    expiredToken => 'One or more of your tokens has expired.',
    malformed => 'The payment data was corrupted in transit.',
    duplicate => 'This payment was already processed.',
    cancelled => 'The payment was cancelled.',
    disconnected => 'The connection was lost before the payment completed.',
    internal => 'Something went wrong while processing the payment.',
  };
}

/// Merchant → payer: the authoritative payment request over BLE (the OFFER).
/// Mirrors the QR the payer scanned so the payer can bind QR ↔ BLE by
/// [merchantId] + [nonce] before paying. [amountPaise] is null for an Open
/// Cash offer (the merchant did not pre-decide an amount — the payer's own
/// entered amount, carried in the TOKEN_TRANSFER, is authoritative instead).
class PaymentOffer {
  final int v;
  final int? amountPaise;
  final String merchantId;
  final String nonce;
  final int ts; // epoch seconds

  const PaymentOffer({
    this.v = kTransferProtocolVersion,
    this.amountPaise,
    required this.merchantId,
    required this.nonce,
    required this.ts,
  });

  /// True when the merchant did not pre-decide an amount (Open Cash) — the
  /// payer supplies the amount instead.
  bool get isOpenCash => amountPaise == null;

  Map<String, dynamic> toJson() => {
    'v': v,
    if (amountPaise != null) 'amount': amountPaise,
    'mid': merchantId,
    'n': nonce,
    'ts': ts,
  };

  static PaymentOffer fromJson(Map<String, dynamic> j) => PaymentOffer(
    v: j['v'] as int,
    amountPaise: j['amount'] as int?,
    merchantId: j['mid'] as String,
    nonce: j['n'] as String,
    ts: j['ts'] as int,
  );
}

/// Payer → merchant: "I accept your offer and am about to send tokens."
class TransferAck {
  final String nonce;
  final bool accepted;

  const TransferAck({required this.nonce, this.accepted = true});

  Map<String, dynamic> toJson() => {'n': nonce, 'ok': accepted};

  static TransferAck fromJson(Map<String, dynamic> j) =>
      TransferAck(nonce: j['n'] as String, accepted: j['ok'] as bool? ?? true);
}

/// Payer → merchant: the ownership-transfer proof + the tokens themselves
/// (PAYMENT_PROTOCOL.md §4.2). [payerSignature] is a Task-8 placeholder; Task 9
/// replaces it with a real Ed25519 signature over the canonical payload.
class TokenTransfer {
  final int v;
  final List<String> tokenIds;
  final List<Token> tokens;
  final int amountPaise;
  final String merchantId;
  final String nonce;
  final int timestamp; // epoch seconds, payer clock
  final String payerId;
  final String payerSignature; // placeholder

  const TokenTransfer({
    this.v = kTransferProtocolVersion,
    required this.tokenIds,
    required this.tokens,
    required this.amountPaise,
    required this.merchantId,
    required this.nonce,
    required this.timestamp,
    required this.payerId,
    required this.payerSignature,
  });

  Map<String, dynamic> toJson() => {
    'v': v,
    'ids': tokenIds,
    'coins': tokens.map((t) => t.toJson()).toList(),
    'amount': amountPaise,
    'mid': merchantId,
    'n': nonce,
    'ts': timestamp,
    'payer': payerId,
    'sig': payerSignature,
  };

  static TokenTransfer fromJson(Map<String, dynamic> j) => TokenTransfer(
    v: j['v'] as int,
    tokenIds: (j['ids'] as List).cast<String>(),
    tokens: (j['coins'] as List)
        .map((c) => Token.fromJson((c as Map).cast<String, dynamic>()))
        .toList(),
    amountPaise: j['amount'] as int,
    merchantId: j['mid'] as String,
    nonce: j['n'] as String,
    timestamp: j['ts'] as int,
    payerId: j['payer'] as String,
    payerSignature: j['sig'] as String,
  );
}

/// Merchant → payer: the transfer was validated and stored (success commit).
class TransferComplete {
  final String nonce;
  final int receivedCount;

  const TransferComplete({required this.nonce, required this.receivedCount});

  Map<String, dynamic> toJson() => {'n': nonce, 'count': receivedCount};

  static TransferComplete fromJson(Map<String, dynamic> j) => TransferComplete(
    nonce: j['n'] as String,
    receivedCount: j['count'] as int,
  );
}

/// Either side → the other: abort with a reason. No value moves on a CANCEL.
class CancelNotice {
  final TransferRejectReason reason;

  const CancelNotice(this.reason);

  Map<String, dynamic> toJson() => {'reason': reason.wire};

  static CancelNotice fromJson(Map<String, dynamic> j) =>
      CancelNotice(TransferRejectReason.fromWire(j['reason'] as String? ?? 'internal'));
}
