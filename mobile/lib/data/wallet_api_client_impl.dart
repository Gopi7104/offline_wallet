import 'dart:convert';
import 'dart:io';
import 'wallet_api_client.dart';

/// A private IP that's unreachable (Wi-Fi off, different network than the dev
/// Mac, no route) leaves Android's TCP connect retrying for 60s+ with no
/// default Dart-side bound, which reads as the UI hanging on "Verifying…"
/// forever. Every call here is best-effort — the offline wallet must fall
/// back quickly, not stall the caller.
const Duration _connectTimeout = Duration(seconds: 5);
const Duration _requestTimeout = Duration(seconds: 8);

/// Concrete HTTP client for wallet endpoints.
class WalletApiClientImpl implements WalletApiClient {
  final String baseUrl;
  final String? accountId; // For the x-account-id header (temp, Task 2).

  WalletApiClientImpl({
    required this.baseUrl,
    this.accountId = 'test-account-1',
  });

  @override
  Future<WalletResponse> getWallet() async {
    final url = Uri.parse('$baseUrl/v1/wallet');
    final client = HttpClient()..connectionTimeout = _connectTimeout;
    final request = await client.getUrl(url).timeout(_requestTimeout);
    if (accountId != null) request.headers.add('x-account-id', accountId!);
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
    if (accountId != null) request.headers.add('x-account-id', accountId!);
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
