import 'dart:convert';
import 'dart:io';
import 'package:offline_wallet/core/identity_headers.dart';
import 'device_api_client.dart';

/// See WalletApiClientImpl: an unreachable backend must fail fast, not hang
/// the caller.
const Duration _connectTimeout = Duration(seconds: 5);
const Duration _requestTimeout = Duration(seconds: 8);

/// Concrete HTTP client for Device Registration. Uses dart:io HttpClient
/// directly (consistent with the wallet/merchant/settlement clients).
class DeviceApiClientImpl implements DeviceApiClient {
  final String baseUrl;
  final IdentityHeaders? identity; // Firebase bearer token or x-account-id (FR-ID-01).

  DeviceApiClientImpl({required this.baseUrl, this.identity});

  Future<void> _addIdentityHeaders(HttpClientRequest request) async {
    final headers = await identity?.call() ?? const {'x-account-id': 'test-account-1'};
    headers.forEach(request.headers.set);
  }

  @override
  Future<DeviceResponse> register({
    required String deviceId,
    required String platform,
    required String deviceModel,
    required String appVersion,
    required String publicKeyHex,
  }) async {
    final url = Uri.parse('$baseUrl/v1/devices/register');
    final client = HttpClient()..connectionTimeout = _connectTimeout;
    final request = await client.postUrl(url).timeout(_requestTimeout);
    request.headers.contentType = ContentType.json;
    await _addIdentityHeaders(request);
    request.write(jsonEncode({
      'deviceId': deviceId,
      'platform': platform,
      'deviceModel': deviceModel,
      'appVersion': appVersion,
      'publicKey': publicKeyHex,
    }));
    final response = await request.close().timeout(_requestTimeout);
    final body = await utf8.decoder.bind(response).join();

    if (response.statusCode != 201) {
      final decoded = _tryDecode(body);
      throw DeviceApiException(
        response.statusCode,
        decoded?['error'] as String? ?? 'UNKNOWN_ERROR',
        decoded?['message'] as String? ?? 'device registration failed: ${response.statusCode}',
      );
    }
    return DeviceResponse.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }

  @override
  Future<DeviceResponse> touchLastSeen(String deviceId) async {
    final url = Uri.parse('$baseUrl/v1/devices/$deviceId/last-seen');
    final client = HttpClient()..connectionTimeout = _connectTimeout;
    final request = await client.postUrl(url).timeout(_requestTimeout);
    await _addIdentityHeaders(request);
    final response = await request.close().timeout(_requestTimeout);
    final body = await utf8.decoder.bind(response).join();

    if (response.statusCode != 200) {
      final decoded = _tryDecode(body);
      throw DeviceApiException(
        response.statusCode,
        decoded?['error'] as String? ?? 'UNKNOWN_ERROR',
        decoded?['message'] as String? ?? 'touch-last-seen failed: ${response.statusCode}',
      );
    }
    return DeviceResponse.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
