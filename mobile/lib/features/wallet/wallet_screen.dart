import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/domain/wallet.dart';
import 'wallet_provider.dart';

/// Wallet screen — displays balance and allows loading funds.
/// Task 2: basic UI showing balance + load button.
/// Task 3+: add auth, offline limits, transaction history, etc.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: Center(
        child: walletAsync.when(
          loading: () => const CircularProgressIndicator(key: Key('loading')),
          error: (err, _) => Text('Error: $err', key: const Key('error')),
          data: (wallet) => _BalanceView(wallet: wallet),
        ),
      ),
    );
  }
}

class _BalanceView extends ConsumerWidget {
  final Wallet? wallet;
  const _BalanceView({required this.wallet});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentWallet = wallet ?? Wallet.empty('unknown');

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Balance',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(
          currentWallet.balance.format(),
          style: Theme.of(context).textTheme.displaySmall,
          key: const Key('balance-display'),
        ),
        const SizedBox(height: 32),
        _LoadButton(currentWallet: currentWallet),
      ],
    );
  }
}

class _LoadButton extends ConsumerStatefulWidget {
  final Wallet currentWallet;
  const _LoadButton({required this.currentWallet});

  @override
  ConsumerState<_LoadButton> createState() => _LoadButtonState();
}

class _LoadButtonState extends ConsumerState<_LoadButton> {
  // Loading is tracked locally and driven ONLY by an explicit button press.
  // The load provider is never watched during build, so opening the screen
  // never triggers a load (QA fix).
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _loading ? null : _onLoadPressed,
          icon: const Icon(Icons.add_circle),
          label: const Text('Load ₹5'),
          key: const Key('load-button'),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, key: Key('load-spinner')),
            ),
          ),
      ],
    );
  }

  Future<void> _onLoadPressed() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      // Trigger the load only now, on explicit press, then refresh the balance.
      ref.invalidate(loadWalletProvider(500));
      await ref.read(loadWalletProvider(500).future);
      ref.invalidate(walletProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Loaded ₹5'), duration: Duration(seconds: 2)),
      );
    } catch (err) {
      messenger.showSnackBar(
        SnackBar(content: Text('Load failed: $err'), duration: const Duration(seconds: 2)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
