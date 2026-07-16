import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:offline_wallet/components/components.dart';
import 'package:offline_wallet/domain/settlement.dart';
import 'package:offline_wallet/theme/theme.dart';

import 'merchant_provider.dart';
import 'pending_settlement_provider.dart';
import 'settlement_provider.dart';

/// Settlement screen (Task 9): Pending Settlement → Settle Now → Processing →
/// Settlement Summary. Redeems the merchant's received tokens at the backend
/// (POST /v1/settlement), surfacing accepted / rejected / duplicate counts and
/// the credited amount + settlement id. Request-level failures (unknown
/// merchant, malformed/empty payload, network) show a Material 3 dialog.
class SettlementScreen extends ConsumerStatefulWidget {
  /// Merchant to settle for. When null, resolved from Merchant Mode.
  final String? merchantId;
  const SettlementScreen({super.key, this.merchantId});

  @override
  ConsumerState<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends ConsumerState<SettlementScreen> {
  String? get _merchantId =>
      widget.merchantId ?? ref.read(merchantModeProvider).valueOrNull?.merchantId;

  void _onSettle() {
    final merchantId = _merchantId;
    final pending = ref.read(pendingSettlementProvider).pending;
    if (merchantId == null || merchantId.isEmpty) {
      showAppInfoDialog(
        context,
        title: 'Merchant not registered',
        message: SettlementErrorKind.unknownMerchant.message,
      );
      return;
    }
    ref.read(settlementControllerProvider.notifier).settle(merchantId, pending);
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingSettlementProvider);
    final ui = ref.watch(settlementControllerProvider);

    // Surface request-level failures as a Material dialog.
    ref.listen<SettlementUiState>(settlementControllerProvider, (prev, next) {
      if (next.phase == SettlementPhase.error && next.error != null) {
        showAppInfoDialog(
          context,
          title: 'Settlement failed',
          message: next.error!.message,
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Settlement')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.base),
        children: [
          if (ui.phase == SettlementPhase.success && ui.result != null)
            _SettlementSummaryCard(result: ui.result!)
          else ...[
            _PendingSettlementCard(state: pending),
            const SizedBox(height: AppSpacing.xl),
            if (pending.hasPending)
              PrimaryButton(
                key: const Key('settle-now-button'),
                label: 'Settle Now',
                icon: Symbols.account_balance_rounded,
                loading: ui.isProcessing,
                onPressed: ui.isProcessing ? null : _onSettle,
              )
            else
              const EmptyState(
                key: Key('settlement-empty'),
                icon: Symbols.inbox_rounded,
                title: 'Nothing to settle',
                message: 'Received offline payments will appear here to settle.',
              ),
            if (ui.isProcessing) ...[
              const SizedBox(height: AppSpacing.xl),
              const Center(
                child: Column(
                  key: Key('settlement-processing'),
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: AppSpacing.m),
                    Text('Processing settlement…'),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _PendingSettlementCard extends StatelessWidget {
  final PendingSettlementState state;
  const _PendingSettlementCard({required this.state});

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
          const Text(
            'PENDING SETTLEMENT',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            state.pendingAmount.format(),
            key: const Key('settlement-pending-amount'),
            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.l),
          Row(
            children: [
              Expanded(
                child: _stat('Tokens', '${state.pendingCount}', const Key('settlement-pending-count')),
              ),
              Container(width: 1, height: 36, color: Colors.white24),
              const SizedBox(width: AppSpacing.base),
              Expanded(
                child: _stat('Settled', state.settled.format(), const Key('settlement-settled-amount')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Key valueKey) {
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

class _SettlementSummaryCard extends ConsumerWidget {
  final SettlementResult result;
  const _SettlementSummaryCard({required this.result});

  Color _statusColor() => switch (result.status) {
        SettlementStatus.success => AppColors.success,
        SettlementStatus.partial => AppColors.warning,
        SettlementStatus.rejected => AppColors.error,
      };

  String _statusLabel() => switch (result.status) {
        SettlementStatus.success => 'Settled',
        SettlementStatus.partial => 'Partially settled',
        SettlementStatus.rejected => 'Rejected',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      key: const Key('settlement-summary'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Icon(
                result.status == SettlementStatus.rejected
                    ? Symbols.error_rounded
                    : Symbols.check_circle_rounded,
                size: 48,
                color: _statusColor(),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            Center(
              child: Text('Settlement Summary', style: AppTypography.textTheme.titleLarge),
            ),
            const SizedBox(height: AppSpacing.xs),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: _statusColor().withValues(alpha: 0.15),
                  borderRadius: AppRadius.pillRadius,
                ),
                child: Text(
                  _statusLabel(),
                  key: const Key('summary-status'),
                  style: TextStyle(color: _statusColor(), fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _row('Amount Credited', result.creditedAmount.format(), const Key('summary-credited')),
            const Divider(height: AppSpacing.xl),
            _row('Accepted Tokens', '${result.accepted}', const Key('summary-accepted')),
            _row('Rejected Tokens', '${result.rejected}', const Key('summary-rejected')),
            _row('Duplicate Tokens', '${result.duplicates}', const Key('summary-duplicates')),
            const Divider(height: AppSpacing.xl),
            _row('Settlement ID', result.settlementId, const Key('summary-settlement-id'), mono: true),
            _row('Ledger ID', result.ledgerId, const Key('summary-ledger-id'), mono: true),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              key: const Key('settlement-done-button'),
              label: 'Done',
              icon: Symbols.done_rounded,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, Key valueKey, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: AppTypography.textTheme.bodyMedium)),
          const SizedBox(width: AppSpacing.base),
          Flexible(
            child: Text(
              value,
              key: valueKey,
              textAlign: TextAlign.right,
              style: mono
                  ? AppTypography.textTheme.bodySmall
                  : AppTypography.textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}
