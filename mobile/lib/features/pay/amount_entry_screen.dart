import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'payment_confirmation_screen.dart';

/// Amount entry — the payer types the amount (in whole rupees) to pay.
/// Converts to integer paise (the wire unit) before continuing.
class AmountEntryScreen extends StatefulWidget {
  final String merchantId;
  const AmountEntryScreen({super.key, required this.merchantId});

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
      MaterialPageRoute(
        builder: (_) => PaymentConfirmationScreen(
          merchantId: widget.merchantId,
          amountPaise: rupees * 100,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Amount')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('amount-field'),
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Amount (₹)',
                prefixText: '₹ ',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('amount-continue'),
              onPressed: _onContinue,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
