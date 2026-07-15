import 'dart:convert';
import 'dart:io';
import 'payment_api_client.dart';

/// See WalletApiClientImpl: an unreachable backend must fail fast, not hang
/// the caller.
const Duration _connectTimeout = Duration(seconds: 5);
const Duration _requestTimeout = Duration(seconds: 8);

/// Concrete HTTP client for the Customer Pay endpoint. Uses dart:io HttpClient
/// directly (consistent with the other clients).
class PaymentApiClientImpl implements PaymentApiClient {
  final String baseUrl;
  final String? accountId; // Payer, via x-account-id (stubbed auth, Task 5).

  PaymentApiClientImpl({
    required this.baseUrl,
    this.accountId = 'test-account-1',
  });

  @override
  Future<PaymentRequestResponse> createPaymentRequest({
    required String merchantId,
    required int amountPaise,
  }) async {
    final url = Uri.parse('$baseUrl/v1/payment/request');
    final client = HttpClient()..connectionTimeout = _connectTimeout;
    final request = await client.postUrl(url).timeout(_requestTimeout);
    request.headers.contentType = ContentType.json;
    if (accountId != null) request.headers.add('x-account-id', accountId!);
    request.write(jsonEncode({'merchantId': merchantId, 'amount': amountPaise}));
    final response = await request.close().timeout(_requestTimeout);
    final body = await utf8.decoder.bind(response).join();

    if (response.statusCode == 201) {
      return PaymentRequestResponse.fromJson(jsonDecode(body) as Map<String, dynamic>);
    }

    // Surface the backend's typed error (INVALID_AMOUNT / MERCHANT_NOT_FOUND / …).
    String code = 'HTTP_${response.statusCode}';
    String message = 'Request failed (${response.statusCode})';
    try {
      final err = jsonDecode(body) as Map<String, dynamic>;
      code = (err['error'] as String?) ?? code;
      message = (err['message'] as String?) ?? message;
    } catch (_) {
      // Non-JSON body; keep the defaults.
    }
    throw PaymentApiException(response.statusCode, code, message);
  }
}
