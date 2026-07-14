import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/app/app.dart';

void main() {
  testWidgets('app boots and shows the skeleton banner', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OfflineWalletApp()));
    expect(find.byKey(const Key('skeleton-banner')), findsOneWidget);
    expect(find.text('Offline Wallet'), findsOneWidget);
  });
}
