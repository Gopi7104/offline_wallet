/// HTTP client for the Settlement endpoint (POST /v1/settlement, Task 9).
abstract interface class SettlementApiClient {
  /// Submit [tokensJson] (each in the `Token.toJson()` wire shape) for
  /// [merchantId]. Returns the parsed response, or throws
  /// [SettlementApiException] with the server's error code on a non-200.
  Future<SettlementResponse> settle({
    required String merchantId,
    required List<Map<String, dynamic>> tokensJson,
  });
}

/// Wire DTO for the settlement response (§5.6).
class SettlementResponse {
  final String settlementId;
  final int accepted;
  final int rejected;
  final int duplicates;
  final int creditedPaise;
  final String ledgerId;
  final String status;

  SettlementResponse({
    required this.settlementId,
    required this.accepted,
    required this.rejected,
    required this.duplicates,
    required this.creditedPaise,
    required this.ledgerId,
    required this.status,
  });

  factory SettlementResponse.fromJson(Map<String, dynamic> json) {
    final credited = json['creditedAmount'] as Map<String, dynamic>;
    return SettlementResponse(
      settlementId: json['settlementId'] as String? ?? '',
      accepted: (json['accepted'] as num).toInt(),
      rejected: (json['rejected'] as num).toInt(),
      duplicates: (json['duplicates'] as num).toInt(),
      creditedPaise: (credited['paise'] as num).toInt(),
      ledgerId: json['ledgerId'] as String? ?? '',
      status: json['status'] as String? ?? 'REJECTED',
    );
  }
}

/// Raised on a non-200 settlement response; carries the server error code.
class SettlementApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;
  SettlementApiException(this.statusCode, this.code, this.message);

  @override
  String toString() => 'SettlementApiException($statusCode $code: $message)';
}
