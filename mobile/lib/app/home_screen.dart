import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/features/receive/merchant_dashboard_screen.dart';
import 'package:offline_wallet/features/receive/merchant_provider.dart';
import 'package:offline_wallet/features/wallet/wallet_screen.dart';

/// Home screen — the app's navigation hub (ARCHITECTURE.md §6.1 `app/`).
/// Task 4: opens the Wallet, and hosts the Merchant Mode toggle that enables
/// Merchant Mode and opens the merchant dashboard.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchantMode = ref.watch(merchantModeProvider);
    final isEnabled = merchantMode.valueOrNull != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Offline Wallet')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              key: const Key('open-wallet'),
              leading: const Icon(Icons.account_balance_wallet),
              title: const Text('Wallet'),
              subtitle: const Text('View balance and load funds'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WalletScreen()),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  key: const Key('merchant-mode-toggle'),
                  secondary: const Icon(Icons.storefront),
                  title: const Text('Merchant Mode'),
                  subtitle: Text(
                    merchantMode.isLoading
                        ? 'Enabling…'
                        : isEnabled
                            ? 'Enabled — accept payments'
                            : 'Turn on to accept payments',
                  ),
                  value: isEnabled,
                  onChanged: merchantMode.isLoading
                      ? null
                      : (on) {
                          final notifier =
                              ref.read(merchantModeProvider.notifier);
                          if (on) {
                            notifier.enable();
                          } else {
                            notifier.disable();
                          }
                        },
                ),
                if (merchantMode.hasError)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      'Could not enable Merchant Mode: ${merchantMode.error}',
                      key: const Key('merchant-mode-error'),
                    ),
                  ),
                if (isEnabled)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        key: const Key('open-merchant-dashboard'),
                        icon: const Icon(Icons.dashboard),
                        label: const Text('Open Merchant Dashboard'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MerchantDashboardScreen(),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
