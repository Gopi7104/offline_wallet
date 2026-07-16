import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:offline_wallet/core/app_config.dart';
import 'package:offline_wallet/data/merchant_api_client_impl.dart';
import 'package:offline_wallet/data/payment_api_client_impl.dart';
import 'package:offline_wallet/data/wallet_api_client_impl.dart';

// On-device networking smoke test (Task 4.1). Runs on the PHYSICAL device and
// hits the real backend at AppConfig.apiBaseUrl through the app's real API
// clients, exercising every flow the app performs. This is the verification for
// the localhost → LAN-IP fix and the Android cleartext network-security config.
//
//   backend:  PORT=3000 node dist/index.js            # binds 0.0.0.0
//   verify:   flutter test integration_test/network_smoke_test.dart -d <deviceId>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const account = 'device-smoke';
  Future<Map<String, String>> identityFor(String accountId) async => {'x-account-id': accountId};
  final wallet =
      WalletApiClientImpl(baseUrl: AppConfig.apiBaseUrl, identity: () => identityFor(account));
  final merchant =
      MerchantApiClientImpl(baseUrl: AppConfig.apiBaseUrl, identity: () => identityFor(account));
  final payment = PaymentApiClientImpl(
      baseUrl: AppConfig.apiBaseUrl, identity: () => identityFor('device-customer'));
  final merchantIdPattern = RegExp(r'^MER-[0-9A-F]{12}$');

  // Fail fast with a clear error instead of hanging if the device cannot reach
  // the backend (dart:io HttpClient has no default timeout).
  Future<T> guarded<T>(String what, Future<T> op) =>
      op.timeout(const Duration(seconds: 10),
          onTimeout: () => throw StateError('TIMEOUT reaching backend during: $what'));

  testWidgets('device reaches backend at ${AppConfig.apiBaseUrl}', (tester) async {
    // ✓ Wallet loads
    final w0 = await guarded('GET /v1/wallet', wallet.getWallet());
    expect(w0.accountId, account);

    // ✓ Load ₹5 works (delta-based so it is robust across repeated runs)
    final before = w0.paise;
    final loaded = await guarded('POST /v1/wallet/load', wallet.loadWallet(500));
    expect(loaded.newBalancePaise, before + 500);

    // ✓ Merchant Mode enables
    final enabled = await guarded('POST /v1/merchant/enable', merchant.enable());
    expect(merchantIdPattern.hasMatch(enabled.merchantId), isTrue);

    // ✓ Merchant dashboard loads
    final dash = await guarded('GET /v1/merchant', merchant.getMerchant());
    expect(dash, isNotNull);
    expect(dash!.merchantId, enabled.merchantId);

    // ✓ Generate QR endpoint works
    final qr = await guarded('POST /v1/merchant/qr', merchant.generateQr(amountPaise: 12345));
    expect(qr.merchantId, enabled.merchantId);
    expect(qr.amountPaise, 12345);
    expect(qr.nonce.isNotEmpty, isTrue);

    // ✓ Customer Pay: payment request validates the merchant + amount (Task 5)
    final pr = await guarded('POST /v1/payment/request',
        payment.createPaymentRequest(merchantId: enabled.merchantId, amountPaise: 2500));
    expect(pr.merchantId, enabled.merchantId);
    expect(pr.amountPaise, 2500);
    expect(pr.status, 'CREATED');
  });
}
