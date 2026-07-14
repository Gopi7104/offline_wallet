import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pay_provider.dart';
import 'payment_success_screen.dart';

/// Payment confirmation — reviews merchant + amount, then creates the payment
/// request via the backend (which validates the merchant + amount). On success
/// it advances to the success screen; on failure it shows the server's message.
class PaymentConfirmationScreen extends ConsumerStatefulWidget {
  final String merchantId;
  final int amountPaise;

  const PaymentConfirmationScreen({
    super.key,
    required this.merchantId,
    required this.amountPaise,
  });

  @override
  ConsumerState<PaymentConfirmationScreen> createState() =>
      _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState
    extends ConsumerState<PaymentConfirmationScreen> {
  bool _submitting = false;
  String? _error;

  String get _amountLabel => '₹${(widget.amountPaise / 100).toStringAsFixed(2)}';

  Future<void> _onConfirm() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final request = await ref.read(paymentRepositoryProvider).createPaymentRequest(
            merchantId: widget.merchantId,
            amountPaise: widget.amountPaise,
          );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PaymentSuccessScreen(request: request)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Payment')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _row(context, 'Merchant', widget.merchantId,
                        const Key('confirm-merchant-id')),
                    const Divider(height: 24),
                    _row(context, 'Amount', _amountLabel,
                        const Key('confirm-amount')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  key: const Key('confirm-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const Spacer(),
            FilledButton.icon(
              key: const Key('confirm-pay-button'),
              onPressed: _submitting ? null : _onConfirm,
              icon: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle),
              label: Text(_submitting ? 'Submitting…' : 'Confirm & Pay'),
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
