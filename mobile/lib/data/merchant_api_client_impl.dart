import 'dart:convert';
import 'dart:io';
import 'package:offline_wallet/core/identity_headers.dart';
import 'merchant_api_client.dart';

/// See WalletApiClientImpl: an unreachable backend must fail fast, not hang
/// the caller (e.g. Merchant Mode toggle stuck on "Enabling…").
const Duration _connectTimeout = Duration(seconds: 5);
const Duration _requestTimeout = Duration(seconds: 8);

/// Concrete HTTP client for Merchant Mode endpoints. Uses dart:io HttpClient
/// directly (consistent with WalletApiClientImpl); a production build would use
/// a robust client such as dio/http.
class MerchantApiClientImpl implements MerchantApiClient {
  final String baseUrl;
  final IdentityHeaders? identity; // Firebase bearer token or x-account-id (FR-ID-01).

  MerchantApiClientImpl({required this.baseUrl, this.identity});

  Future<void> _addIdentityHeaders(HttpClientRequest request) async {
    final headers = await identity?.call() ?? const {'x-account-id': 'test-account-1'};
    headers.forEach(request.headers.set);
  }

  @override
  Future<MerchantResponse> enable({String? displayName}) async {
    final url = Uri.parse('$baseUrl/v1/merchant/enable');
    final client = HttpClient()..connectionTimeout = _connectTimeout;
    final request = await client.postUrl(url).timeout(_requestTimeout);
    request.headers.contentType = ContentType.json;
    await _addIdentityHeaders(request);
    request.write(jsonEncode(displayName == null ? {} : {'displayName': displayName}));
    final response = await request.close().timeout(_requestTimeout);

    if (response.statusCode != 201) {
      throw Exception('enable merchant failed: ${response.statusCode}');
    }
    final body = await utf8.decoder.bind(response).join();
    return MerchantResponse.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }

  @override
  Future<MerchantResponse?> getMerchant() async {
    final url = Uri.parse('$baseUrl/v1/merchant');
    final client = HttpClient()..connectionTimeout = _connectTimeout;
    final request = await client.getUrl(url).timeout(_requestTimeout);
    await _addIdentityHeaders(request);
    final response = await request.close().timeout(_requestTimeout);

    if (response.statusCode == 404) {
      await response.drain<void>();
      return null;
    }
    if (response.statusCode != 200) {
      throw Exception('getMerchant failed: ${response.statusCode}');
    }
    final body = await utf8.decoder.bind(response).join();
    return MerchantResponse.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }

  /// POST /v1/merchant/qr — create a Payment Request and generate its QR
  /// (Task 6.7). `amountPaise` present → Fixed Amount; omitted → Open Amount.
  @override
  Future<QrResponse> generateQr({int? amountPaise}) async {
    final url = Uri.parse('$baseUrl/v1/merchant/qr');
    final client = HttpClient()..connectionTimeout = _connectTimeout;
    final request = await client.postUrl(url).timeout(_requestTimeout);
    request.headers.contentType = ContentType.json;
    await _addIdentityHeaders(request);
    request.write(jsonEncode(amountPaise == null ? {} : {'amountPaise': amountPaise}));
    final response = await request.close().timeout(_requestTimeout);

    if (response.statusCode != 201) {
      throw Exception('generateQr failed: ${response.statusCode}');
    }
    final body = await utf8.decoder.bind(response).join();
    return QrResponse.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }
}
