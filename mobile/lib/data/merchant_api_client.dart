/// HTTP client for Merchant Mode endpoints (talks to the backend).
abstract interface class MerchantApiClient {
  /// POST /v1/merchant/enable — switch into Merchant Mode.
  Future<MerchantResponse> enable({String? displayName});

  /// GET /v1/merchant — merchant dashboard, or null (404) if not enabled.
  Future<MerchantResponse?> getMerchant();

  /// POST /v1/merchant/qr — generate a placeholder payment QR payload.
  Future<QrResponse> generateQr({int? amountPaise});
}

/// Wire DTO for the merchant dashboard.
class MerchantResponse {
  final String merchantId;
  final String accountId;
  final String displayName;
  final int pendingSettlementPaise;
  final int settledPaise;
  final int totalPaise;

  MerchantResponse({
    required this.merchantId,
    required this.accountId,
    required this.displayName,
    required this.pendingSettlementPaise,
    required this.settledPaise,
    required this.totalPaise,
  });

  factory MerchantResponse.fromJson(Map<String, dynamic> json) {
    final wallet = json['wallet'] as Map<String, dynamic>;
    return MerchantResponse(
      merchantId: json['merchantId'] as String,
      accountId: json['accountId'] as String,
      displayName: json['displayName'] as String,
      pendingSettlementPaise:
          (wallet['pendingSettlement']['paise'] as num).toInt(),
      settledPaise: (wallet['settled']['paise'] as num).toInt(),
      totalPaise: (wallet['total']['paise'] as num).toInt(),
    );
  }
}

/// Wire DTO for the placeholder QR payload.
class QrResponse {
  final int v;
  final String merchantId;
  final String nonce;
  final String ts;
  final int? amountPaise;

  QrResponse({
    required this.v,
    required this.merchantId,
    required this.nonce,
    required this.ts,
    this.amountPaise,
  });

  factory QrResponse.fromJson(Map<String, dynamic> json) {
    return QrResponse(
      v: (json['v'] as num).toInt(),
      merchantId: json['merchantId'] as String,
      nonce: json['nonce'] as String,
      ts: json['ts'] as String,
      amountPaise:
          json['amountPaise'] == null ? null : (json['amountPaise'] as num).toInt(),
    );
  }
}
