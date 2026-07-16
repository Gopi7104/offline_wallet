import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:offline_wallet/components/components.dart';
import 'package:offline_wallet/theme/theme.dart';

/// Success screen — the offline token transfer completed: the customer's
/// tokens were handed to the merchant over BLE and the merchant returned a
/// signed TRANSFER_COMPLETE. Value has moved (unlike the old backend
/// placeholder); settlement happens later (Task 9).
class PaymentSuccessScreen extends StatefulWidget {
  final String merchantId;
  final int amountPaise;
  final int tokenCount;

  const PaymentSuccessScreen({
    super.key,
    required this.merchantId,
    required this.amountPaise,
    required this.tokenCount,
  });

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600))
    ..forward();

  String get _amountLabel => '₹${(widget.amountPaise / 100).toStringAsFixed(2)}';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _copyReceipt() async {
    final text = 'Offline Wallet receipt\n'
        'Merchant: ${widget.merchantId}\n'
        'Amount: $_amountLabel\n'
        'Tokens: ${widget.tokenCount}\n'
        'Status: PAID (offline)';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Receipt copied to clipboard'),
          duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Success'), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          const SizedBox(height: AppSpacing.base),
          Center(
            child: ScaleTransition(
              scale: CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    shape: BoxShape.circle),
                child: const Icon(Symbols.check_circle_rounded,
                    size: 64, color: AppColors.success),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Payment sent',
            key: const Key('success-title'),
            textAlign: TextAlign.center,
            style: AppTypography.textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Column(
                children: [
                  _row(context, 'Merchant', widget.merchantId,
                      const Key('success-merchant-name')),
                  const Divider(height: AppSpacing.xl),
                  _row(context, 'Amount', _amountLabel, const Key('success-amount')),
                  const Divider(height: AppSpacing.xl),
                  _row(context, 'Tokens sent', '${widget.tokenCount}',
                      const Key('success-token-count')),
                  const Divider(height: AppSpacing.xl),
                  _row(context, 'Status', 'Paid (offline)', const Key('success-status')),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          SecondaryButton(
              label: 'Share Receipt',
              icon: Symbols.share_rounded,
              onPressed: _copyReceipt),
          const SizedBox(height: AppSpacing.xxxl),
          PrimaryButton(
            key: const Key('success-done'),
            label: 'Done',
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, Key valueKey) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.textTheme.bodyMedium),
        Flexible(
          child: Text(
            value,
            key: valueKey,
            textAlign: TextAlign.right,
            style: AppTypography.textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}
