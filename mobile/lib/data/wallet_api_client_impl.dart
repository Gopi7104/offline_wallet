import 'dart:convert';
import 'dart:io';
import 'package:offline_wallet/core/identity_headers.dart';
import 'wallet_api_client.dart';

/// A private IP that's unreachable (Wi-Fi off, different network than the dev
/// Mac, no route) leaves Android's TCP connect retrying for 60s+ with no
/// default Dart-side bound, which reads as the UI hanging on "Verifying…"
/// forever. Every call here is best-effort — the offline wallet must fall
/// back quickly, not stall the caller.
const Duration _connectTimeout = Duration(seconds: 5);
// Render free-tier instances spin down after ~15 min idle; the next request
// pays a cold-start wake-up (often 20-45s) before the app responds at all.
// This must outlast that wake-up, or every first-request-after-idle looks
// like "server unreachable" even though the backend is fine.
const Duration _requestTimeout = Duration(seconds: 45);

/// Concrete HTTP client for wallet endpoints.
class WalletApiClientImpl implements WalletApiClient {
  final String baseUrl;
  final IdentityHeaders? identity; // Firebase bearer token or x-account-id (FR-ID-01).

  WalletApiClientImpl({required this.baseUrl, this.identity});

  Future<void> _addIdentityHeaders(HttpClientRequest request) async {
    final headers = await identity?.call() ?? const {'x-account-id': 'test-account-1'};
    headers.forEach(request.headers.set);
  }

  @override
  Future<WalletResponse> getWallet() async {
    final url = Uri.parse('$baseUrl/v1/wallet');
    final client = HttpClient()..connectionTimeout = _connectTimeout;
    final request = await client.getUrl(url).timeout(_requestTimeout);
    await _addIdentityHeaders(request);
    final response = await request.close().timeout(_requestTimeout);

    if (response.statusCode != 200) {
      throw Exception('getWallet failed: ${response.statusCode}');
    }

    final body = await utf8.decoder.bind(response).join();
    return WalletResponse.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }

  @override
  Future<LoadResponse> loadWallet(int amountPaise) async {
    final url = Uri.parse('$baseUrl/v1/wallet/load');
    final client = HttpClient()..connectionTimeout = _connectTimeout;
    final request = await client.postUrl(url).timeout(_requestTimeout);
    request.headers.contentType = ContentType.json;
    await _addIdentityHeaders(request);
    request.write(jsonEncode({'amount': amountPaise}));
    final response = await request.close().timeout(_requestTimeout);
    final body = await utf8.decoder.bind(response).join();

    if (response.statusCode != 201) {
      final decoded = _tryDecode(body);
      throw WalletApiException(
        response.statusCode,
        decoded?['error'] as String? ?? 'UNKNOWN_ERROR',
        decoded?['message'] as String? ?? 'loadWallet failed: ${response.statusCode}',
      );
    }

    return LoadResponse.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
