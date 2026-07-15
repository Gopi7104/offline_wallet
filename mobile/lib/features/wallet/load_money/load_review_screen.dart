import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:offline_wallet/components/components.dart';
import 'package:offline_wallet/theme/theme.dart';
import 'bank_account_screen.dart';

/// Review — confirms amount, projected balance, and (default) bank account
/// before the user picks/confirms a bank account and enters their UPI PIN.
class LoadReviewScreen extends StatelessWidget {
  final int amountPaise;
  final int currentBalancePaise;

  const LoadReviewScreen({super.key, required this.amountPaise, required this.currentBalancePaise});

  String _fmt(int paise) => '₹${(paise / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final projected = currentBalancePaise + amountPaise;

    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                _row('Amount', _fmt(amountPaise), valueKey: const Key('review-amount')),
                const Divider(height: AppSpacing.xl),
                _row('Current Balance', _fmt(currentBalancePaise), valueKey: const Key('review-current-balance')),
                const Divider(height: AppSpacing.xl),
                _row('Wallet After Load', _fmt(projected), valueKey: const Key('review-projected-balance')),
                const Divider(height: AppSpacing.xl),
                _row('Bank Account', kDefaultBankAccount.displayLabel, valueKey: const Key('review-bank-account')),
                const Divider(height: AppSpacing.xl),
                _row('Estimated Total', _fmt(amountPaise), valueKey: const Key('review-total')),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            'This is a prototype — money is simulated. No real UPI transfer occurs.',
            style: AppTypography.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxxl),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  key: const Key('review-back'),
                  label: 'Back',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: AppSpacing.base),
              Expanded(
                child: PrimaryButton(
                  key: const Key('review-continue'),
                  label: 'Continue',
                  icon: Symbols.arrow_forward_rounded,
                  onPressed: () => Navigator.of(context).push(sharedAxisRoute(
                    BankAccountScreen(amountPaise: amountPaise, currentBalancePaise: currentBalancePaise),
                  )),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Key? valueKey}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.textTheme.bodyMedium),
        const SizedBox(width: AppSpacing.base),
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
