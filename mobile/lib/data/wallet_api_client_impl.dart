import 'dart:convert';
import 'dart:io';
import 'wallet_api_client.dart';

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
    final request = await HttpClient().getUrl(url);
    if (accountId != null) request.headers.add('x-account-id', accountId!);
    final response = await request.close();

    if (response.statusCode != 200) {
      throw Exception('getWallet failed: ${response.statusCode}');
    }

    final body = await utf8.decoder.bind(response).join();
    return WalletResponse.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }

  @override
  Future<LoadResponse> loadWallet(int amountPaise) async {
    final url = Uri.parse('$baseUrl/v1/wallet/load');
    final request = await HttpClient().postUrl(url);
    request.headers.contentType = ContentType.json;
    if (accountId != null) request.headers.add('x-account-id', accountId!);
    request.write(jsonEncode({'amount': amountPaise}));
    final response = await request.close();

    if (response.statusCode != 201) {
      throw Exception('loadWallet failed: ${response.statusCode}');
    }

    final body = await utf8.decoder.bind(response).join();
    return LoadResponse.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }
}
