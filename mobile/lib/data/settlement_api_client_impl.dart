import 'dart:convert';
import 'dart:io';
import 'package:offline_wallet/core/identity_headers.dart';
import 'settlement_api_client.dart';

/// See WalletApiClientImpl: an unreachable backend must fail fast, not hang
/// the merchant on "Processing…" forever.
const Duration _connectTimeout = Duration(seconds: 5);
// See WalletApiClientImpl: must outlast a Render free-tier cold-start wake-up.
const Duration _requestTimeout = Duration(seconds: 45);

/// Concrete HTTP client for POST /v1/settlement. Uses dart:io HttpClient
/// directly (consistent with the wallet/merchant clients).
class SettlementApiClientImpl implements SettlementApiClient {
  final String baseUrl;
  final IdentityHeaders? identity; // Firebase bearer token or x-account-id (FR-ID-01).

  SettlementApiClientImpl({required this.baseUrl, this.identity});

  @override
  Future<SettlementResponse> settle({
    required String merchantId,
    required List<Map<String, dynamic>> tokensJson,
  }) async {
    final url = Uri.parse('$baseUrl/v1/settlement');
    final client = HttpClient()..connectionTimeout = _connectTimeout;
    final request = await client.postUrl(url).timeout(_requestTimeout);
    request.headers.contentType = ContentType.json;
    final headers = await identity?.call() ?? const {'x-account-id': 'test-account-1'};
    headers.forEach(request.headers.set);
    request.write(jsonEncode({'merchantId': merchantId, 'tokens': tokensJson}));
    final response = await request.close().timeout(_requestTimeout);
    final body = await utf8.decoder.bind(response).join();

    if (response.statusCode != 200) {
      final decoded = _tryDecode(body);
      throw SettlementApiException(
        response.statusCode,
        decoded?['error'] as String? ?? 'UNKNOWN_ERROR',
        decoded?['message'] as String? ?? 'settlement failed: ${response.statusCode}',
      );
    }

    return SettlementResponse.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
