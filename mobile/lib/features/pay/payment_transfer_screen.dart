import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:offline_wallet/components/components.dart';
import 'package:offline_wallet/theme/theme.dart';

import 'payment_session_controller.dart';
import 'payment_success_screen.dart';

/// Drives the customer half of the offline payment over BLE: Connecting →
/// Sending → (Verifying) → Success. Shows progress and, on any
/// failure/cancel, a Material dialog before returning so the user can retry.
class PaymentTransferScreen extends ConsumerStatefulWidget {
  final PaymentSessionParams params;
  const PaymentTransferScreen({super.key, required this.params});

  @override
  ConsumerState<PaymentTransferScreen> createState() => _PaymentTransferScreenState();
}

class _PaymentTransferScreenState extends ConsumerState<PaymentTransferScreen> {
  bool _handledTerminal = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paymentSessionProvider(widget.params).notifier).start();
    });
  }

  void _onTerminal(PaymentSessionState state) {
    if (_handledTerminal) return;
    _handledTerminal = true;
    if (state.status == PaymentSessionStatus.success) {
      Navigator.of(context).pushReplacement(sharedAxisRoute(
        PaymentSuccessScreen(
          merchantId: widget.params.merchantId,
          amountPaise: state.amountPaise,
          tokenCount: state.tokenCount,
        ),
      ));
    } else {
      _showFailure(state);
    }
  }

  Future<void> _showFailure(PaymentSessionState state) async {
    final cancelled = state.status == PaymentSessionStatus.cancelled;
    await showAppInfoDialog(
      context,
      title: cancelled ? 'Payment cancelled' : 'Payment failed',
      message: state.reason?.message ?? state.statusMessage,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PaymentSessionState>(paymentSessionProvider(widget.params), (prev, next) {
      if (next.isTerminal) _onTerminal(next);
    });
    final state = ref.watch(paymentSessionProvider(widget.params));
    final amountLabel = '₹${(state.amountPaise / 100).toStringAsFixed(2)}';
    final active = !state.isTerminal;

    return PopScope(
      canPop: false, // block accidental back-swipe mid-transfer
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Paying'),
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: AnimatedLoading(size: 64)),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                amountLabel,
                textAlign: TextAlign.center,
                style: AppTypography.balanceMedium,
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                state.statusMessage,
                key: const Key('transfer-status'),
                textAlign: TextAlign.center,
                style: AppTypography.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xxxl),
              if (active)
                SecondaryButton(
                  key: const Key('transfer-cancel-button'),
                  label: 'Cancel',
                  icon: Symbols.close_rounded,
                  onPressed: () =>
                      ref.read(paymentSessionProvider(widget.params).notifier).cancel(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
