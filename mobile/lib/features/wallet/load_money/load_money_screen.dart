import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:offline_wallet/components/components.dart';
import 'package:offline_wallet/features/wallet/wallet_provider.dart';
import 'package:offline_wallet/theme/theme.dart';
import 'load_review_screen.dart';

/// Wallet holding cap (FR-ISS-06). Mirrors the backend's
/// `WalletService.DEFAULT_MAX_HOLDING_PAISE` so an over-cap request can be
/// disabled client-side before it's sent — the backend remains the source of
/// truth and re-validates on every load.
const int kMaxWalletHoldingPaise = 50000 * 100;

const List<int> kQuickLoadAmountsRupees = [100, 250, 500, 1000, 2000];

/// Load Money — amount entry, the first step of the wallet funding flow
/// (Task 6.6). Replaces the old developer-only "Load ₹5" button.
class LoadMoneyScreen extends ConsumerStatefulWidget {
  const LoadMoneyScreen({super.key});

  @override
  ConsumerState<LoadMoneyScreen> createState() => _LoadMoneyScreenState();
}

class _LoadMoneyScreenState extends ConsumerState<LoadMoneyScreen> {
  final _controller = TextEditingController();
  int? _selectedQuickAmount;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _amountPaise {
    final rupees = int.tryParse(_controller.text.trim());
    if (rupees == null || rupees <= 0) return 0;
    return rupees * 100;
  }

  void _selectQuick(int rupees) {
    setState(() {
      _selectedQuickAmount = rupees;
      _controller.text = rupees.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(walletProvider);
    final currentBalancePaise = walletAsync.valueOrNull?.balance.paise ?? 0;
    final amount = _amountPaise;
    final projected = currentBalancePaise + amount;
    final hasInput = _controller.text.trim().isNotEmpty;

    String? error;
    if (hasInput && amount <= 0) {
      error = 'Enter a whole rupee amount greater than zero';
    } else if (hasInput && projected > kMaxWalletHoldingPaise) {
      error = 'This would exceed the ₹50,000 wallet limit';
    }

    final valid = amount > 0 && error == null;

    return Scaffold(
      appBar: AppBar(title: const Text('Load Money')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          GlassCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT WALLET BALANCE',
                        style: AppTypography.textTheme.labelLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '₹${(currentBalancePaise / 100).toStringAsFixed(2)}',
                        key: const Key('load-money-current-balance'),
                        style: AppTypography.balanceMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.base),
                const Icon(Symbols.account_balance_wallet_rounded, color: AppColors.textSecondary),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text('Quick Amounts', style: AppTypography.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.base),
          Wrap(
            spacing: AppSpacing.base,
            runSpacing: AppSpacing.base,
            children: kQuickLoadAmountsRupees
                .map((r) => _QuickAmountChip(
                      rupees: r,
                      selected: _selectedQuickAmount == r,
                      onTap: () => _selectQuick(r),
                    ))
                .toList(),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text('Custom Amount', style: AppTypography.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.base),
          TextField(
            key: const Key('load-money-amount-field'),
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppTypography.balanceMedium,
            decoration: const InputDecoration(prefixText: '₹ ', hintText: '0'),
            onChanged: (_) => setState(() => _selectedQuickAmount = null),
          ),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.base),
            Text(error, key: const Key('load-money-error'), style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: AppSpacing.xxxl),
          PrimaryButton(
            key: const Key('load-money-continue'),
            label: 'Continue',
            icon: Symbols.arrow_forward_rounded,
            onPressed: valid
                ? () => Navigator.of(context).push(sharedAxisRoute(LoadReviewScreen(
                      amountPaise: amount,
                      currentBalancePaise: currentBalancePaise,
                    )))
                : null,
          ),
        ],
      ),
    );
  }
}

class _QuickAmountChip extends StatelessWidget {
  final int rupees;
  final bool selected;
  final VoidCallback onTap;
  const _QuickAmountChip({required this.rupees, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('quick-amount-$rupees'),
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.m),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.18) : AppColors.surfaceRaised,
          borderRadius: AppRadius.pillRadius,
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          '₹$rupees',
          style: TextStyle(
            color: selected ? AppColors.primary : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
