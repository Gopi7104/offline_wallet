import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:offline_wallet/components/components.dart';
import 'package:offline_wallet/theme/theme.dart';
import 'load_money/load_money_screen.dart';
import 'wallet_provider.dart';

/// Wallet screen — displays the offline-cash balance and allows loading funds.
class WalletScreen extends ConsumerWidget {
  /// Named so the funding flow (Load Money → … → Success) can
  /// `popUntil(ModalRoute.withName(routeName))` to return here directly,
  /// regardless of how many screens deep it pushed.
  static const routeName = '/wallet';

  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Offline cash = the local token wallet (spendable offline; decreases on a
    // payment, survives restart). This is the wallet's real balance for
    // offline use; settlement of the backend balance lands in Task 9.
    final offlineCash = ref.watch(tokenBalanceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.base),
        children: [
          BalanceCard(
            targetValue: offlineCash.paise / 100.0,
            format: (v) => '₹${v.toStringAsFixed(2)}',
            label: 'WALLET BALANCE',
            subtitle: 'Available offline',
            valueKey: const Key('balance-display'),
            trailing: const Icon(Symbols.account_balance_wallet_rounded, color: Colors.white70),
          ),
          const SizedBox(height: AppSpacing.xl),
          const _LoadButton(),
        ],
      ),
    );
  }
}

class _LoadButton extends StatelessWidget {
  const _LoadButton();

  @override
  Widget build(BuildContext context) {
    // Opening this screen never triggers a load (QA fix, preserved) — the
    // funding flow only calls the load endpoint after the user completes
    // amount entry → review → bank selection → UPI PIN (Task 6.6).
    return PrimaryButton(
      key: const Key('load-money-button'),
      label: 'Load Money',
      icon: Symbols.add_circle_rounded,
      onPressed: () => Navigator.of(context).push(sharedAxisRoute(const LoadMoneyScreen())),
    );
  }
}
