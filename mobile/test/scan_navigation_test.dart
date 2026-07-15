import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/features/pay/scan_qr_screen.dart';

String validQr(String merchantId) => base64Url
    .encode(utf8.encode(jsonEncode({
      'v': 1,
      'typ': 'offer-req',
      'mid': merchantId,
      'n': 'nonce-xyz',
      'ts': 1752480000,
    })))
    .replaceAll('=', '');

// Uses ScanQrScreen's synchronous test seam (debugInitialScan) so no camera is
// needed and there is no async-stream / autofocus-cursor flakiness.
Widget _harness(String scanned) => ProviderScope(
      child: MaterialApp(home: ScanQrScreen(debugInitialScan: scanned)),
    );

void main() {
  testWidgets('a valid scan auto-navigates Scan → Merchant Summary',
      (tester) async {
    await tester.pumpWidget(_harness(validQr('MER-ABC123DEF456')));
    // post-frame callback fires _handleRaw → pushReplacement; then build + settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('summary-merchant-id')), findsOneWidget);
    expect(find.text('MER-ABC123DEF456'), findsOneWidget);
    // The Summary screen is the entry to the (Task 5) Amount → Confirmation
    // chain, exercised by pay_flow_test.
    expect(find.byKey(const Key('summary-continue')), findsOneWidget);
  });

  testWidgets('a malformed QR shows a friendly error and does not navigate',
      (tester) async {
    await tester.pumpWidget(_harness('not-a-valid-qr'));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('scan-error')), findsOneWidget);
    expect(find.byKey(const Key('summary-merchant-id')), findsNothing);
  });

  testWidgets('an unsupported version shows a version error and does not navigate',
      (tester) async {
    await tester.pumpWidget(_harness(base64Url
        .encode(utf8.encode(jsonEncode({
          'v': 99,
          'typ': 'offer-req',
          'mid': 'MER-ABC123DEF456',
          'n': 'n',
          'ts': 1752480000,
        })))
        .replaceAll('=', '')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('scan-error')), findsOneWidget);
    expect(find.textContaining('Unsupported QR version'), findsOneWidget);
    expect(find.byKey(const Key('summary-merchant-id')), findsNothing);
  });
}
