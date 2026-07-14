import 'package:flutter/material.dart';
import 'package:offline_wallet/domain/payment.dart';

/// Success screen — the placeholder payment request was created and validated by
/// the backend. Task 5: NO value has moved yet (the offline coin transfer +
/// settlement land in later tasks); this confirms the request was accepted.
class PaymentSuccessScreen extends StatelessWidget {
  final PaymentRequest request;
  const PaymentSuccessScreen({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Success')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Icon(Icons.check_circle, size: 96, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              'Payment request created',
              key: const Key('success-title'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _row(context, 'Merchant', request.merchantName,
                        const Key('success-merchant-name')),
                    const Divider(height: 24),
                    _row(context, 'Amount', request.amount.format(),
                        const Key('success-amount')),
                    const Divider(height: 24),
                    _row(context, 'Status', request.status,
                        const Key('success-status')),
                    const Divider(height: 24),
                    _row(context, 'Request', request.paymentRequestId,
                        const Key('success-request-id')),
                  ],
                ),
              ),
            ),
            const Spacer(),
            FilledButton(
              key: const Key('success-done'),
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, Key valueKey) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Flexible(
          child: Text(
            value,
            key: valueKey,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}
