/// HTTP client for Device Registration endpoints (talks to the backend;
/// production hardening §1, extended by Task 9 with the device public key —
/// FR-PAY-04/FR-ID-02/03). Reuses the existing registration endpoints; no new
/// API surface.
abstract interface class DeviceApiClient {
  /// POST /v1/devices/register
  Future<DeviceResponse> register({
    required String deviceId,
    required String platform,
    required String deviceModel,
    required String appVersion,
    required String publicKeyHex,
  });

  /// POST /v1/devices/:deviceId/last-seen
  Future<DeviceResponse> touchLastSeen(String deviceId);
}

/// Wire DTO for a registered device.
class DeviceResponse {
  final String deviceId;
  final String accountId;
  final bool active;

  DeviceResponse({required this.deviceId, required this.accountId, required this.active});

  factory DeviceResponse.fromJson(Map<String, dynamic> json) => DeviceResponse(
    deviceId: json['deviceId'] as String,
    accountId: json['accountId'] as String,
    active: json['active'] as bool,
  );
}

/// Typed API failure carrying the backend's error code + message (mirrors
/// WalletApiException/MerchantApiException).
class DeviceApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  DeviceApiException(this.statusCode, this.code, this.message);

  @override
  String toString() => message.isNotEmpty ? message : code;
}
