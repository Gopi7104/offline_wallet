import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/domain/merchant.dart';
import 'merchant_provider.dart';

/// Merchant dashboard (FR-MER-01/02). Shows the Merchant ID and the two wallet
/// buckets (received-pending vs settled), and generates a placeholder payment
/// QR payload. No BLE, QR rendering, settlement or crypto in Task 4.
class MerchantDashboardScreen extends ConsumerStatefulWidget {
  const MerchantDashboardScreen({super.key});

  @override
  ConsumerState<MerchantDashboardScreen> createState() =>
      _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState
    extends ConsumerState<MerchantDashboardScreen> {
  QrPayload? _payload;
  bool _generating = false;
  String? _error;

  Future<void> _onGenerateQr() async {
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final repo = ref.read(merchantRepositoryProvider);
      final payload = await repo.generateQrPayload(kMerchantAccountId);
      setState(() => _payload = payload);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final merchant = ref.watch(merchantModeProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Merchant Mode')),
      body: merchant == null
          ? const Center(
              child: Text(
                'Merchant Mode is not enabled.',
                key: Key('merchant-not-enabled'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _MerchantIdCard(merchant: merchant),
                const SizedBox(height: 16),
                _WalletCard(wallet: merchant.wallet),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  key: const Key('generate-qr-button'),
                  onPressed: _generating ? null : _onGenerateQr,
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Generate QR'),
                ),
                if (_generating)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Center(
                      child: CircularProgressIndicator(key: Key('qr-spinner')),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text('QR failed: $_error', key: const Key('qr-error')),
                  ),
                if (_payload != null) _QrPayloadCard(payload: _payload!),
              ],
            ),
    );
  }
}

class _MerchantIdCard extends StatelessWidget {
  final Merchant merchant;
  const _MerchantIdCard({required this.merchant});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Merchant ID', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            SelectableText(
              merchant.merchantId,
              key: const Key('merchant-id'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              merchant.displayName,
              key: const Key('merchant-name'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  final MerchantWallet wallet;
  const _WalletCard({required this.wallet});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _row(context, 'Received (pending settlement)',
                wallet.pendingSettlement.format(), const Key('pending-amount')),
            const SizedBox(height: 8),
            _row(context, 'Settled', wallet.settled.format(),
                const Key('settled-amount')),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, Key valueKey) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(value,
            key: valueKey, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _QrPayloadCard extends StatelessWidget {
  final QrPayload payload;
  const _QrPayloadCard({required this.payload});

  @override
  Widget build(BuildContext context) {
    // Placeholder: display the payload as text. Real QR rendering (qr_flutter)
    // arrives with the offline receive task.
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Payment QR payload (placeholder)',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SelectableText(
                'v: ${payload.v}\n'
                'merchantId: ${payload.merchantId}\n'
                'nonce: ${payload.nonce}\n'
                'ts: ${payload.ts}'
                '${payload.amountPaise != null ? '\namount(paise): ${payload.amountPaise}' : ''}',
                key: const Key('qr-payload'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
