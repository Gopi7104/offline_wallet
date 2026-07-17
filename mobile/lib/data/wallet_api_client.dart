import 'package:offline_wallet/domain/token.dart';

/// HTTP client for wallet endpoints (talks to the backend).
/// For now, uses dart:io HttpClient directly. In production, use
/// a robust client like dio or http.
abstract interface class WalletApiClient {
  /// GET /v1/wallet — fetch current balance.
  Future<WalletResponse> getWallet();

  /// POST /v1/wallet/load — load funds from the bank.
  /// Throws [WalletApiException] on a 4xx (invalid amount / holding cap exceeded).
  Future<LoadResponse> loadWallet(int amountPaise);
}

/// Typed API failure carrying the backend's error code + message (mirrors
/// `PaymentApiException`), so the funding UI can tell a holding-cap rejection
/// (FR-ISS-06) apart from an invalid amount or a generic server error.
class WalletApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  WalletApiException(this.statusCode, this.code, this.message);

  bool get isHoldingCapExceeded => code == 'HOLDING_CAP_EXCEEDED';

  @override
  String toString() => message.isNotEmpty ? message : code;
}

class WalletResponse {
  final String accountId;
  final int paise;
  final String currency;

  WalletResponse({
    required this.accountId,
    required this.paise,
    required this.currency,
  });

  factory WalletResponse.fromJson(Map<String, dynamic> json) {
    return WalletResponse(
      accountId: json['accountId'] as String,
      paise: (json['balance']['paise'] as num).toInt(),
      currency: json['balance']['currency'] as String,
    );
  }
}

class LoadResponse {
  final String accountId;
  final int newBalancePaise;
  final String currency;
  /// The exact tokens the backend just minted for this load (Task 10) — real
  /// Ed25519-signed coins, wire-shaped identically to `Token.toJson()`. The
  /// wallet must store and later spend these exact tokens, never a
  /// locally-generated placeholder.
  final List<Token> tokens;

  LoadResponse({
    required this.accountId,
    required this.newBalancePaise,
    required this.currency,
    required this.tokens,
  });

  factory LoadResponse.fromJson(Map<String, dynamic> json) {
    return LoadResponse(
      accountId: json['accountId'] as String,
      newBalancePaise: (json['newBalance']['paise'] as num).toInt(),
      currency: json['newBalance']['currency'] as String,
      tokens: ((json['tokens'] as List?) ?? const [])
          .map((t) => Token.fromJson((t as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}
