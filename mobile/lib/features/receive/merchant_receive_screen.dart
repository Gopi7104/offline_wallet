import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:offline_wallet/components/components.dart';
import 'package:offline_wallet/theme/theme.dart';

import 'merchant_receive_controller.dart';

/// Merchant Receive Payment (Task 8; Open Cash): Fixed Amount (enter an
/// amount) or Open Cash (leave it to the customer) → show a QR + advertise
/// over BLE → Waiting → Receiving → Verifying → Payment received. Displays the
/// amount (or "Open Cash" until a transfer arrives), Pending Settlement, and
/// the received token count.
class MerchantReceiveScreen extends ConsumerStatefulWidget {
  const MerchantReceiveScreen({super.key});

  @override
  ConsumerState<MerchantReceiveScreen> createState() => _MerchantReceiveScreenState();
}

class _MerchantReceiveScreenState extends ConsumerState<MerchantReceiveScreen> {
  final _amountController = TextEditingController();
  String? _amountError;
  bool _openCash = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _onStart() {
    if (_openCash) {
      setState(() => _amountError = null);
      ref.read(merchantReceiveControllerProvider.notifier).start(null);
      return;
    }
    final rupees = int.tryParse(_amountController.text.trim());
    if (rupees == null || rupees <= 0) {
      setState(() => _amountError = 'Enter a whole rupee amount greater than zero');
      return;
    }
    setState(() => _amountError = null);
    ref.read(merchantReceiveControllerProvider.notifier).start(rupees * 100);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(merchantReceiveControllerProvider);
    final started = state.status != MerchantReceiveStatus.idle;

    return Scaffold(
      appBar: AppBar(title: const Text('Receive Payment (BLE)')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.base),
        children: [
          if (!started)
            _AmountEntryCard(
              controller: _amountController,
              errorText: _amountError,
              openCash: _openCash,
              onOpenCashChanged: (v) => setState(() {
                _openCash = v;
                _amountError = null;
              }),
              onStart: _onStart,
            )
          else
            _ReceiveStatusCard(state: state),
          if (started) ...[
            const SizedBox(height: AppSpacing.xl),
            _MerchantWalletCard(state: state),
            const SizedBox(height: AppSpacing.xl),
            SecondaryButton(
              key: const Key('receive-stop-button'),
              label: 'Stop',
              icon: Symbols.stop_circle_rounded,
              onPressed: () => ref.read(merchantReceiveControllerProvider.notifier).stop(),
            ),
          ],
        ],
      ),
    );
  }
}

class _AmountEntryCard extends StatelessWidget {
  final TextEditingController controller;
  final String? errorText;
  final bool openCash;
  final ValueChanged<bool> onOpenCashChanged;
  final VoidCallback onStart;
  const _AmountEntryCard({
    required this.controller,
    required this.errorText,
    required this.openCash,
    required this.onOpenCashChanged,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Request a payment', style: AppTypography.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.l),
            SwitchListTile(
              key: const Key('receive-open-cash-switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Open Cash'),
              subtitle: const Text('Let the customer enter the amount'),
              value: openCash,
              onChanged: onOpenCashChanged,
            ),
            const SizedBox(height: AppSpacing.l),
            TextField(
              key: const Key('receive-amount-field'),
              controller: controller,
              enabled: !openCash,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTypography.textTheme.titleMedium,
              decoration: InputDecoration(
                labelText: 'Amount (₹)',
                prefixText: '₹ ',
                errorText: errorText,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              key: const Key('receive-start-button'),
              label: openCash ? 'Show QR & Start (Open Cash)' : 'Show QR & Start',
              icon: Symbols.qr_code_2_rounded,
              onPressed: onStart,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiveStatusCard extends StatelessWidget {
  final MerchantReceiveState state;
  const _ReceiveStatusCard({required this.state});

  bool get _showQr =>
      state.status == MerchantReceiveStatus.waiting ||
      state.status == MerchantReceiveStatus.receiving;

  bool get _done => state.status == MerchantReceiveStatus.received;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              _done ? Symbols.check_circle_rounded : Symbols.contactless_rounded,
              size: 40,
              color: _done ? AppColors.success : AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              state.statusMessage,
              key: const Key('receive-status'),
              textAlign: TextAlign.center,
              style: AppTypography.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.l),
            if (_showQr && state.qrData.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.mdRadius,
                ),
                padding: const EdgeInsets.all(AppSpacing.m),
                child: QrImageView(
                  key: const Key('receive-qr'),
                  data: state.qrData,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
            if (_showQr) ...[
              const SizedBox(height: AppSpacing.m),
              Text(
                'Ask the customer to scan this code.',
                style: AppTypography.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MerchantWalletCard extends StatelessWidget {
  final MerchantReceiveState state;
  const _MerchantWalletCard({required this.state});

  String get _amountLabel {
    final paise = state.amountPaise;
    return paise == null ? 'Open Cash' : '₹${(paise / 100).toStringAsFixed(2)}';
  }

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
          _stat('Requested amount', _amountLabel, const Key('receive-amount-label')),
          const SizedBox(height: AppSpacing.l),
          Row(
            children: [
              Expanded(
                child: _stat('Pending Settlement', state.pendingSettlement.format(),
                    const Key('receive-pending-amount')),
              ),
              Expanded(
                child: _stat('Tokens received', '${state.receivedCount}',
                    const Key('receive-token-count')),
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
