/// HTTP client for the Customer Pay endpoint (Task 5).
abstract interface class PaymentApiClient {
  /// POST /v1/payment/request — validate merchant + amount, return the request.
  /// Throws [PaymentApiException] on a 4xx (invalid amount / merchant not found).
  Future<PaymentRequestResponse> createPaymentRequest({
    required String merchantId,
    required int amountPaise,
  });
}

/// Typed API failure carrying the backend's error code + message.
class PaymentApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  PaymentApiException(this.statusCode, this.code, this.message);

  @override
  String toString() => message.isNotEmpty ? message : code;
}

/// Wire DTO for a created payment request.
class PaymentRequestResponse {
  final String paymentRequestId;
  final String payerAccountId;
  final String merchantId;
  final String merchantName;
  final int amountPaise;
  final String currency;
  final String status;

  PaymentRequestResponse({
    required this.paymentRequestId,
    required this.payerAccountId,
    required this.merchantId,
    required this.merchantName,
    required this.amountPaise,
    required this.currency,
    required this.status,
  });

  factory PaymentRequestResponse.fromJson(Map<String, dynamic> json) {
    final amount = json['amount'] as Map<String, dynamic>;
    return PaymentRequestResponse(
      paymentRequestId: json['paymentRequestId'] as String,
      payerAccountId: json['payerAccountId'] as String,
      merchantId: json['merchantId'] as String,
      merchantName: json['merchantName'] as String,
      amountPaise: (amount['paise'] as num).toInt(),
      currency: amount['currency'] as String,
      status: json['status'] as String,
    );
  }
}
