import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:offline_wallet/components/components.dart';
import 'package:offline_wallet/domain/denominations.dart';
import 'package:offline_wallet/domain/transfer.dart';
import 'package:offline_wallet/features/security/payment_step_up_provider.dart';
import 'package:offline_wallet/features/wallet/wallet_provider.dart';
import 'package:offline_wallet/theme/theme.dart';
import 'payment_session_controller.dart';
import 'payment_transfer_screen.dart';

/// Payment confirmation — reviews the merchant + amount and the offline cash
/// available, checks the wallet can make the exact amount, requires a
/// fingerprint (falling back to the app PIN), then hands off to the BLE
/// transfer screen which moves the tokens.
class PaymentConfirmationScreen extends ConsumerStatefulWidget {
  final String merchantId;
  final int amountPaise;
  final String nonce;

  const PaymentConfirmationScreen({
    super.key,
    required this.merchantId,
    required this.amountPaise,
    required this.nonce,
  });

  @override
  ConsumerState<PaymentConfirmationScreen> createState() =>
      _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState
    extends ConsumerState<PaymentConfirmationScreen> {
  String? _error;

  String get _amountLabel => '₹${(widget.amountPaise / 100).toStringAsFixed(2)}';

  Future<void> _onConfirm() async {
    setState(() => _error = null);

    // Offline-cash pre-check: don't ask for auth if we can't pay.
    final tokens = ref.read(tokenWalletProvider);
    if (!hasSufficientBalance(widget.amountPaise, tokens)) {
      setState(() => _error = TransferRejectReason.insufficientBalance.message);
      return;
    }
    if (selectExact(widget.amountPaise, tokens) == null) {
      setState(() => _error = TransferRejectReason.insufficientTokens.message);
      return;
    }

    final authenticator = ref.read(paymentStepUpAuthenticatorProvider);
    final authenticated = await authenticator.authenticate(
      context,
      reason: 'Confirm payment of $_amountLabel to ${widget.merchantId}',
    );
    if (!authenticated || !mounted) return;

    Navigator.of(context).push(sharedAxisRoute(
      PaymentTransferScreen(
        params: PaymentSessionParams(
          merchantId: widget.merchantId,
          nonce: widget.nonce,
          amountPaise: widget.amountPaise,
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final offlineCash = ref.watch(tokenBalanceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Payment')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                _row(context, 'Merchant', widget.merchantId,
                    const Key('confirm-merchant-id')),
                const Divider(height: AppSpacing.xl),
                _row(context, 'Amount', _amountLabel, const Key('confirm-amount')),
                const Divider(height: AppSpacing.xl),
                _row(context, 'Offline cash available', offlineCash.format(),
                    const Key('confirm-offline-balance')),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.m),
              child: Text(
                _error!,
                key: const Key('confirm-error'),
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          const SizedBox(height: AppSpacing.xxl),
          PrimaryButton(
            key: const Key('confirm-pay-button'),
            label: 'Confirm & Pay',
            icon: Symbols.check_circle_rounded,
            onPressed: _onConfirm,
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
