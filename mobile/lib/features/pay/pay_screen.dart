import 'package:flutter/material.dart';
import 'merchant_summary_screen.dart';

/// Pay screen — entry to the Customer Pay flow (ARCHITECTURE.md §6.1 `pay/`).
/// Task 5: "Scan QR" is a PLACEHOLDER — real camera/QR scanning (mobile_scanner)
/// lands in a later task. The button stands in for a scan by letting the user
/// enter the Merchant ID a QR would carry.
class PayScreen extends StatelessWidget {
  const PayScreen({super.key});

  Future<void> _onScanQr(BuildContext context) async {
    final merchantId = await showDialog<String>(
      context: context,
      builder: (_) => const _ScanPlaceholderDialog(),
    );
    if (merchantId == null || merchantId.trim().isEmpty) return;
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MerchantSummaryScreen(merchantId: merchantId.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pay')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.qr_code_scanner, size: 96),
              const SizedBox(height: 16),
              Text(
                'Scan a merchant QR to pay',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Placeholder: camera scanning arrives in a later task.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('scan-qr-button'),
                onPressed: () => _onScanQr(context),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan QR'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanPlaceholderDialog extends StatefulWidget {
  const _ScanPlaceholderDialog();

  @override
  State<_ScanPlaceholderDialog> createState() => _ScanPlaceholderDialogState();
}

class _ScanPlaceholderDialogState extends State<_ScanPlaceholderDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Scan QR (placeholder)'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Enter the Merchant ID the QR would contain:'),
          const SizedBox(height: 12),
          TextField(
            key: const Key('scan-merchant-id-field'),
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'MER-XXXXXXXXXXXX',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('scan-confirm'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Use'),
        ),
      ],
    );
  }
}
