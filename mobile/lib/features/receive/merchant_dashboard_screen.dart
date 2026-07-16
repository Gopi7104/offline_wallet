import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:offline_wallet/components/components.dart';
import 'package:offline_wallet/domain/merchant.dart';
import 'package:offline_wallet/theme/theme.dart';
import 'merchant_provider.dart';
import 'merchant_receive_screen.dart';
import 'pending_settlement_provider.dart';
import 'settlement_screen.dart';

/// Merchant dashboard (FR-MER-01/02). Shows the Merchant ID, the two wallet
/// buckets, Pending Settlement, and the way in to the single payment flow:
/// Receive Payment (BLE) — Fixed Amount or Open Cash, QR shown, BLE
/// advertising started, all from that one screen.
class MerchantDashboardScreen extends ConsumerWidget {
  const MerchantDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchant = ref.watch(merchantModeProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Merchant Dashboard')),
      body: merchant == null
          ? const Center(
              child: Text(
                'Merchant Mode is not enabled.',
                key: Key('merchant-not-enabled'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.base),
              children: [
                _MerchantHeroCard(merchant: merchant),
                const SizedBox(height: AppSpacing.xl),
                SecondaryButton(
                  key: const Key('open-ble-merchant-button'),
                  label: 'Receive Payment (BLE)',
                  icon: Symbols.contactless_rounded,
                  onPressed: () => Navigator.of(context).push(
                    sharedAxisRoute(const MerchantReceiveScreen()),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _PendingSettlementSection(merchant: merchant),
              ],
            ),
    );
  }
}

class _MerchantHeroCard extends StatelessWidget {
  final Merchant merchant;
  const _MerchantHeroCard({required this.merchant});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: AppRadius.xlRadius,
        gradient: const LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MERCHANT ID',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    SelectableText(
                      merchant.merchantId,
                      key: const Key('merchant-id'),
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      merchant.displayName,
                      key: const Key('merchant-name'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.base),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Symbols.storefront_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: _heroStat(
                  'Pending Settlement',
                  merchant.wallet.pendingSettlement.format(),
                  const Key('pending-amount'),
                ),
              ),
              Container(width: 1, height: 36, color: Colors.white24),
              const SizedBox(width: AppSpacing.base),
              Expanded(
                child: _heroStat(
                  'Settled',
                  merchant.wallet.settled.format(),
                  const Key('settled-amount'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value, Key valueKey) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          key: valueKey,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// Pending Settlement section (Task 9). Shown only when the merchant has
/// received offline payments awaiting settlement. Routes to the Settlement
/// screen, where the tokens are redeemed at the backend.
class _PendingSettlementSection extends ConsumerWidget {
  final Merchant merchant;
  const _PendingSettlementSection({required this.merchant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingSettlementProvider);
    if (!pending.hasPending) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Card(
        key: const Key('pending-settlement-card'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Symbols.pending_actions_rounded, color: AppColors.warning),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: Text('Pending Settlement', style: AppTypography.textTheme.titleLarge),
                  ),
                  Text(
                    pending.pendingAmount.format(),
                    key: const Key('dashboard-pending-settlement-amount'),
                    style: AppTypography.textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${pending.pendingCount} token(s) received offline, ready to settle.',
                style: AppTypography.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.l),
              PrimaryButton(
                key: const Key('open-settlement-button'),
                label: 'Settle Received Payments',
                icon: Symbols.account_balance_rounded,
                onPressed: () => Navigator.of(context).push(
                  sharedAxisRoute(SettlementScreen(merchantId: merchant.merchantId)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
