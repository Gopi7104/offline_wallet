import 'package:offline_wallet/core/money.dart';

/// HTTP client for wallet endpoints (talks to the backend).
/// For now, uses dart:io HttpClient directly. In production, use
/// a robust client like dio or http.
abstract interface class WalletApiClient {
  /// GET /v1/wallet — fetch current balance.
  Future<WalletResponse> getWallet();

  /// POST /v1/wallet/load — load funds from the bank.
  Future<LoadResponse> loadWallet(int amountPaise);
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

  LoadResponse({
    required this.accountId,
    required this.newBalancePaise,
    required this.currency,
  });

  factory LoadResponse.fromJson(Map<String, dynamic> json) {
    return LoadResponse(
      accountId: json['accountId'] as String,
      newBalancePaise: (json['newBalance']['paise'] as num).toInt(),
      currency: json['newBalance']['currency'] as String,
    );
  }
}
