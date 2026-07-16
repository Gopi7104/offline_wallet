import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:offline_wallet/components/components.dart';
import 'package:offline_wallet/features/wallet/wallet_screen.dart';
import 'package:offline_wallet/theme/theme.dart';

/// Success — the load endpoint minted the tokens and the wallet balance is
/// updated. "Done" returns to the Wallet screen the flow started from.
class LoadSuccessScreen extends StatefulWidget {
  final int amountPaise;
  final int newBalancePaise;

  const LoadSuccessScreen({super.key, required this.amountPaise, required this.newBalancePaise});

  @override
  State<LoadSuccessScreen> createState() => _LoadSuccessScreenState();
}

class _LoadSuccessScreenState extends State<LoadSuccessScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _fmt(int paise) => '₹${(paise / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            const SizedBox(height: AppSpacing.xxxl),
            Center(
              child: ScaleTransition(
                scale: CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Symbols.check_circle_rounded, size: 64, color: AppColors.success),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Money Added',
              key: const Key('load-success-title'),
              textAlign: TextAlign.center,
              style: AppTypography.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              _fmt(widget.amountPaise),
              key: const Key('load-success-amount'),
              textAlign: TextAlign.center,
              style: AppTypography.balanceLarge,
            ),
            const SizedBox(height: AppSpacing.xxl),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Updated Wallet Balance', style: AppTypography.textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _fmt(widget.newBalancePaise),
                    key: const Key('load-success-new-balance'),
                    style: AppTypography.balanceMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            PrimaryButton(
              key: const Key('load-success-done'),
              label: 'Done',
              onPressed: () => Navigator.of(context).popUntil(ModalRoute.withName(WalletScreen.routeName)),
            ),
          ],
        ),
      ),
    );
  }
}
