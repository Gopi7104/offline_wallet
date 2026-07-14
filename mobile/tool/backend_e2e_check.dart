// End-to-end integration check: drives the REAL Flutter data-layer API clients
// (dart:io HttpClient) against a running backend to prove the two halves speak
// the same wire contract. Not a unit test — run against a live server:
//
//   (cd backend && PORT=3999 node dist/index.js &)
//   (cd mobile   && dart run tool/backend_e2e_check.dart http://localhost:3999)
//
// Exits 0 on success, 1 on the first mismatch.
import 'dart:io';

import 'package:offline_wallet/data/merchant_api_client_impl.dart';
import 'package:offline_wallet/data/wallet_api_client_impl.dart';

void _check(bool ok, String label) {
  stdout.writeln('${ok ? "PASS" : "FAIL"}  $label');
  if (!ok) exitCode = 1;
}

Future<void> main(List<String> args) async {
  final baseUrl = args.isNotEmpty ? args.first : 'http://localhost:3000';
  const account = 'e2e-merchant';

  final merchant = MerchantApiClientImpl(baseUrl: baseUrl, accountId: account);
  final wallet = WalletApiClientImpl(baseUrl: baseUrl, accountId: account);

  final merchantIdPattern = RegExp(r'^MER-[0-9A-F]{12}$');

  // --- Merchant Mode ---
  final enabled = await merchant.enable();
  _check(merchantIdPattern.hasMatch(enabled.merchantId),
      'enable() returns a well-formed Merchant ID (${enabled.merchantId})');
  _check(enabled.pendingSettlementPaise == 0 && enabled.settledPaise == 0,
      'new merchant wallet is empty');

  final fetched = await merchant.getMerchant();
  _check(fetched != null && fetched.merchantId == enabled.merchantId,
      'getMerchant() returns the same Merchant ID (idempotent)');

  final qr1 = await merchant.generateQr(amountPaise: 12345);
  _check(qr1.merchantId == enabled.merchantId && qr1.amountPaise == 12345 && qr1.nonce.isNotEmpty,
      'generateQr() returns a payload bound to the merchant with the amount');

  final qr2 = await merchant.generateQr();
  _check(qr2.nonce != qr1.nonce, 'each QR gets a fresh nonce');

  // --- Wallet (proves the pre-existing wallet slice still works too) ---
  final w0 = await wallet.getWallet();
  _check(w0.paise == 0, 'wallet starts at zero for a fresh account');

  final loaded = await wallet.loadWallet(1500);
  _check(loaded.newBalancePaise == 1500, 'loadWallet(1500 paise) → balance ₹15.00');

  stdout.writeln(exitCode == 0 ? '\nALL CHECKS PASSED' : '\nSOME CHECKS FAILED');
}
