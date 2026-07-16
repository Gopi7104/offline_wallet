import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:offline_wallet/components/components.dart';
import 'package:offline_wallet/theme/theme.dart';
import 'payment_confirmation_screen.dart';

/// Amount entry — the payer types the amount (in whole rupees) to pay.
/// Converts to integer paise (the wire unit) before continuing.
class AmountEntryScreen extends StatefulWidget {
  final String merchantId;
  final String nonce;
  const AmountEntryScreen({super.key, required this.merchantId, required this.nonce});

  @override
  State<AmountEntryScreen> createState() => _AmountEntryScreenState();
}

class _AmountEntryScreenState extends State<AmountEntryScreen> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onContinue() {
    final rupees = int.tryParse(_controller.text.trim());
    if (rupees == null || rupees <= 0) {
      setState(() => _error = 'Enter a whole rupee amount greater than zero');
      return;
    }
    setState(() => _error = null);
    Navigator.of(context).push(
      sharedAxisRoute(
        PaymentConfirmationScreen(
          merchantId: widget.merchantId,
          amountPaise: rupees * 100,
          nonce: widget.nonce,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Amount')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('How much are you paying?', style: AppTypography.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xl),
            TextField(
              key: const Key('amount-field'),
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTypography.balanceMedium,
              decoration: InputDecoration(
                labelText: 'Amount (₹)',
                prefixText: '₹ ',
                errorText: _error,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(key: const Key('amount-continue'), label: 'Continue', onPressed: _onContinue),
          ],
        ),
      ),
    );
  }
}
