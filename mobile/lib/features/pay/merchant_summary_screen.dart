import 'package:flutter/material.dart';
import 'amount_entry_screen.dart';

/// Merchant summary — shows the scanned merchant before entering an amount.
/// Task 5: the QR carries only the Merchant ID, so that is what we display; the
/// merchant's name is confirmed by the backend when the payment request is
/// created (shown on the success screen).
class MerchantSummaryScreen extends StatelessWidget {
  final String merchantId;
  const MerchantSummaryScreen({super.key, required this.merchantId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Merchant')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.storefront, size: 40),
                    const SizedBox(height: 12),
                    Text('Paying merchant',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 4),
                    SelectableText(
                      merchantId,
                      key: const Key('summary-merchant-id'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            FilledButton(
              key: const Key('summary-continue'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AmountEntryScreen(merchantId: merchantId),
                ),
              ),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
