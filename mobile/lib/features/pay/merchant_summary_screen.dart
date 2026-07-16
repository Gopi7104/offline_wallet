import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:offline_wallet/components/components.dart';
import 'package:offline_wallet/domain/merchant.dart';
import 'package:offline_wallet/theme/theme.dart';
import 'amount_entry_screen.dart';
import 'payment_confirmation_screen.dart';

/// Merchant summary — shows the scanned merchant before the payer commits to
/// an amount. A Fixed Amount QR already carries the amount, so Continue skips
/// straight to Confirmation; an Open Cash QR routes to Amount Entry so the
/// payer can type the amount, which then travels in the BLE TOKEN_TRANSFER
/// for the merchant to verify (no backend call either way — the whole
/// payment is offline over BLE).
class MerchantSummaryScreen extends StatelessWidget {
  final QrPayload payload;
  const MerchantSummaryScreen({super.key, required this.payload});

  bool get _isFixedAmount => payload.isFixedAmount;

  String get _amountLabel =>
      _isFixedAmount ? '₹${(payload.amountPaise! / 100).toStringAsFixed(2)}' : 'Open Amount';

  void _onContinue(BuildContext context) {
    if (_isFixedAmount) {
      Navigator.of(context).push(
        sharedAxisRoute(
          PaymentConfirmationScreen(
            merchantId: payload.merchantId,
            amountPaise: payload.amountPaise!,
            nonce: payload.nonce,
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        sharedAxisRoute(
          AmountEntryScreen(merchantId: payload.merchantId, nonce: payload.nonce),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Merchant')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: AppColors.surfaceRaised, shape: BoxShape.circle),
                    child: const Icon(Symbols.storefront_rounded, size: 28, color: AppColors.primary),
                  ),
                  const SizedBox(height: AppSpacing.base),
                  Text('Paying merchant', style: AppTypography.textTheme.labelLarge),
                  const SizedBox(height: AppSpacing.xs),
                  SelectableText(
                    payload.merchantId,
                    key: const Key('summary-merchant-id'),
                    style: AppTypography.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.l),
                  const Divider(),
                  const SizedBox(height: AppSpacing.l),
                  Text(
                    _isFixedAmount ? 'Requested amount' : 'Payment type',
                    style: AppTypography.textTheme.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _amountLabel,
                    key: const Key('summary-amount'),
                    style: AppTypography.balanceMedium,
                  ),
                  if (!_isFixedAmount) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      "You'll enter the amount next.",
                      key: const Key('summary-open-amount-hint'),
                      style: AppTypography.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const Spacer(),
            PrimaryButton(
              key: const Key('summary-continue'),
              label: _isFixedAmount ? 'Continue to Pay' : 'Enter Amount',
              icon: Symbols.arrow_forward_rounded,
              onPressed: () => _onContinue(context),
            ),
          ],
        ),
      ),
    );
  }
}
