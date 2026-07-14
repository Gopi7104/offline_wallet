import 'dart:convert';
import 'dart:io';
import 'merchant_api_client.dart';

/// Concrete HTTP client for Merchant Mode endpoints. Uses dart:io HttpClient
/// directly (consistent with WalletApiClientImpl); a production build would use
/// a robust client such as dio/http.
class MerchantApiClientImpl implements MerchantApiClient {
  final String baseUrl;
  final String? accountId; // For the x-account-id header (stubbed auth, Task 4).

  MerchantApiClientImpl({
    required this.baseUrl,
    this.accountId = 'test-account-1',
  });

  @override
  Future<MerchantResponse> enable({String? displayName}) async {
    final url = Uri.parse('$baseUrl/v1/merchant/enable');
    final request = await HttpClient().postUrl(url);
    request.headers.contentType = ContentType.json;
    if (accountId != null) request.headers.add('x-account-id', accountId!);
    request.write(jsonEncode(displayName == null ? {} : {'displayName': displayName}));
    final response = await request.close();

    if (response.statusCode != 201) {
      throw Exception('enable merchant failed: ${response.statusCode}');
    }
    final body = await utf8.decoder.bind(response).join();
    return MerchantResponse.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }

  @override
  Future<MerchantResponse?> getMerchant() async {
    final url = Uri.parse('$baseUrl/v1/merchant');
    final request = await HttpClient().getUrl(url);
    if (accountId != null) request.headers.add('x-account-id', accountId!);
    final response = await request.close();

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

  @override
  Future<QrResponse> generateQr({int? amountPaise}) async {
    final url = Uri.parse('$baseUrl/v1/merchant/qr');
    final request = await HttpClient().postUrl(url);
    request.headers.contentType = ContentType.json;
    if (accountId != null) request.headers.add('x-account-id', accountId!);
    request.write(jsonEncode(amountPaise == null ? {} : {'amount': amountPaise}));
    final response = await request.close();

    if (response.statusCode != 201) {
      throw Exception('generateQr failed: ${response.statusCode}');
    }
    final body = await utf8.decoder.bind(response).join();
    return QrResponse.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }
}
