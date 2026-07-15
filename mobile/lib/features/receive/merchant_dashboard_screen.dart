import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:offline_wallet/components/components.dart';
import 'package:offline_wallet/domain/merchant.dart';
import 'package:offline_wallet/domain/qr_codec.dart';
import 'package:offline_wallet/theme/theme.dart';
import 'merchant_provider.dart';
import 'merchant_receive_screen.dart';

/// A single row in the (local, placeholder) Recent Requests list. Task 6.7 is
/// a vertical slice with no persistence — this list lives only in widget
/// state and seeds a few illustrative rows, same as a fresh PhonePe
/// Business/BharatPe merchant dashboard would show sample activity.
class _RecentRequest {
  final String amountLabel;
  final String status;
  const _RecentRequest({required this.amountLabel, required this.status});
}

/// Merchant dashboard (FR-MER-01/02). Shows the Merchant ID, the two wallet
/// buckets, and the Payment Request flow (Task 6.7): the merchant requests a
/// Fixed Amount or leaves it Open, and a QR is generated for the customer to
/// scan.
class MerchantDashboardScreen extends ConsumerStatefulWidget {
  const MerchantDashboardScreen({super.key});

  @override
  ConsumerState<MerchantDashboardScreen> createState() =>
      _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState
    extends ConsumerState<MerchantDashboardScreen> {
  final _amountController = TextEditingController();
  QrPayload? _payload;
  bool _generating = false;
  String? _error;
  String? _amountFieldError;

  final List<_RecentRequest> _recentRequests = [
    const _RecentRequest(amountLabel: '₹250', status: 'Generated'),
    const _RecentRequest(amountLabel: '₹99', status: 'Pending'),
    const _RecentRequest(amountLabel: 'Open Amount', status: 'Generated'),
  ];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  int? get _enteredRupees {
    final text = _amountController.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  Future<void> _onRequestFixedAmount() async {
    final rupees = _enteredRupees;
    if (rupees == null || rupees <= 0) {
      setState(() => _amountFieldError = 'Enter an amount to request a fixed payment');
      return;
    }
    await _generate(amountPaise: rupees * 100, label: '₹$rupees');
  }

  Future<void> _onRequestOpenAmount() async {
    await _generate(amountPaise: null, label: 'Open Amount');
  }

  Future<void> _generate({required int? amountPaise, required String label}) async {
    setState(() {
      _generating = true;
      _error = null;
      _amountFieldError = null;
    });
    try {
      final repo = ref.read(merchantRepositoryProvider);
      final payload =
          await repo.generateQrPayload(kMerchantAccountId, amountPaise: amountPaise);
      setState(() {
        _payload = payload;
        _recentRequests.insert(0, _RecentRequest(amountLabel: label, status: 'Generated'));
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                _PaymentRequestCard(
                  amountController: _amountController,
                  amountFieldError: _amountFieldError,
                  generating: _generating,
                  onRequestFixedAmount: _onRequestFixedAmount,
                  onRequestOpenAmount: _onRequestOpenAmount,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.base),
                    child: Text(
                      'QR failed: $_error',
                      key: const Key('qr-error'),
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                if (_payload != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _GeneratedRequestCard(payload: _payload!),
                ],
                const SizedBox(height: AppSpacing.xl),
                _RecentRequestsSection(requests: _recentRequests),
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

class _PaymentRequestCard extends StatelessWidget {
  final TextEditingController amountController;
  final String? amountFieldError;
  final bool generating;
  final VoidCallback onRequestFixedAmount;
  final VoidCallback onRequestOpenAmount;

  const _PaymentRequestCard({
    required this.amountController,
    required this.amountFieldError,
    required this.generating,
    required this.onRequestFixedAmount,
    required this.onRequestOpenAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Payment Request', style: AppTypography.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.l),
            TextField(
              key: const Key('payment-amount-field'),
              controller: amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTypography.textTheme.titleMedium,
              decoration: InputDecoration(
                labelText: 'Amount (₹)',
                prefixText: '₹ ',
                errorText: amountFieldError,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Leave empty to let the customer enter the amount.',
              key: const Key('payment-amount-hint'),
              style: AppTypography.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              key: const Key('request-fixed-amount-button'),
              label: 'Request Fixed Amount',
              icon: Symbols.request_quote_rounded,
              loading: generating,
              onPressed: generating ? null : onRequestFixedAmount,
            ),
            const SizedBox(height: AppSpacing.m),
            SecondaryButton(
              key: const Key('request-open-amount-button'),
              label: 'Request Open Amount',
              icon: Symbols.all_inclusive_rounded,
              onPressed: generating ? null : onRequestOpenAmount,
            ),
          ],
        ),
      ),
    );
  }
}

class _GeneratedRequestCard extends StatelessWidget {
  final QrPayload payload;
  const _GeneratedRequestCard({required this.payload});

  @override
  Widget build(BuildContext context) {
    final amountLabel =
        payload.isFixedAmount ? '₹${(payload.amountPaise! / 100).toStringAsFixed(0)}' : 'Open Amount';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Generated Payment Request', style: AppTypography.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.l),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.mdRadius,
              ),
              padding: const EdgeInsets.all(AppSpacing.m),
              child: QrImageView(
                key: const Key('qr-payload'),
                data: encodeMerchantQr(payload),
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            Text(
              payload.isFixedAmount ? 'Requested Amount' : 'Payment Type',
              style: AppTypography.textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              amountLabel,
              key: const Key('generated-amount-label'),
              style: AppTypography.balanceMedium,
            ),
            const SizedBox(height: AppSpacing.base),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: AppRadius.pillRadius,
              ),
              child: const Text(
                'Generated',
                key: Key('generated-status'),
                style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              'Ask the customer to scan this code.',
              style: AppTypography.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentRequestsSection extends StatelessWidget {
  final List<_RecentRequest> requests;
  const _RecentRequestsSection({required this.requests});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Recent Requests', style: AppTypography.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.m),
            for (var i = 0; i < requests.length; i++) ...[
              if (i > 0) const Divider(height: AppSpacing.xl),
              _RecentRequestRow(request: requests[i], index: i),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecentRequestRow extends StatelessWidget {
  final _RecentRequest request;
  final int index;
  const _RecentRequestRow({required this.request, required this.index});

  @override
  Widget build(BuildContext context) {
    final isGenerated = request.status == 'Generated';
    return Row(
      key: Key('recent-request-$index'),
      children: [
        Expanded(
          child: Text(
            request.amountLabel,
            style: AppTypography.textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s, vertical: 2),
          decoration: BoxDecoration(
            color: (isGenerated ? AppColors.success : AppColors.warning).withValues(alpha: 0.15),
            borderRadius: AppRadius.pillRadius,
          ),
          child: Text(
            request.status,
            style: TextStyle(
              color: isGenerated ? AppColors.success : AppColors.warning,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
