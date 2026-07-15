import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:offline_wallet/components/components.dart';
import 'package:offline_wallet/features/auth/auth_provider.dart';
import 'package:offline_wallet/features/pay/pay_screen.dart';
import 'package:offline_wallet/features/receive/merchant_dashboard_screen.dart';
import 'package:offline_wallet/features/receive/merchant_provider.dart';
import 'package:offline_wallet/features/settings/settings_screen.dart';
import 'package:offline_wallet/features/wallet/wallet_provider.dart';
import 'package:offline_wallet/features/wallet/wallet_screen.dart';
import 'package:offline_wallet/theme/theme.dart';

/// Home dashboard — the app's navigation hub (ARCHITECTURE.md §6.1 `app/`).
/// Task 6.5: premium dashboard (balance hero, quick actions, Merchant Mode,
/// recent activity). Same navigation targets and `Key`s as before — only the
/// visuals changed.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchantMode = ref.watch(merchantModeProvider);
    final isEnabled = merchantMode.valueOrNull != null;
    // Offline cash = the local token wallet (spendable offline; decreases on a
    // payment). This is the customer's real balance for offline use; the
    // backend balance is a settlement-side concern (Task 9).
    final offlineCash = ref.watch(tokenBalanceProvider);
    final user = ref.watch(authControllerProvider).valueOrNull?.user;
    final greetingName = user == null || user.isGuest ? 'Guest' : (user.displayName ?? user.email ?? 'there');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Wallet'),
        actions: [
          IconButton(
            icon: const Icon(Symbols.settings_rounded),
            onPressed: () => Navigator.of(context).push(sharedAxisRoute(const SettingsScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.base),
        children: [
          Text('Welcome back', style: AppTypography.textTheme.bodyMedium),
          Text(greetingName, style: AppTypography.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.l),
          BalanceCard(
            targetValue: offlineCash.paise / 100.0,
            format: (v) => '₹${v.toStringAsFixed(2)}',
            label: 'BALANCE',
            subtitle: 'Available offline',
            valueKey: const Key('home-balance'),
            trailing: const Icon(Symbols.account_balance_wallet_rounded, color: Colors.white70),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Quick actions', style: AppTypography.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.s),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  actionKey: const Key('open-wallet'),
                  icon: Symbols.account_balance_wallet_rounded,
                  label: 'Wallet',
                  onTap: () => Navigator.of(context).push(sharedAxisRoute(
                    const WalletScreen(),
                    settings: const RouteSettings(name: WalletScreen.routeName),
                  )),
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: _QuickAction(
                  actionKey: const Key('open-pay'),
                  icon: Symbols.qr_code_scanner_rounded,
                  label: 'Pay',
                  onTap: () => Navigator.of(context).push(sharedAxisRoute(const PayScreen())),
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: _QuickAction(
                  icon: Symbols.storefront_rounded,
                  label: 'Merchant',
                  onTap: isEnabled
                      ? () => Navigator.of(context).push(sharedAxisRoute(const MerchantDashboardScreen()))
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Symbols.storefront_rounded, color: AppColors.textSecondary),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: Text('Merchant Mode', style: AppTypography.textTheme.titleMedium),
                      ),
                      Switch(
                        key: const Key('merchant-mode-toggle'),
                        value: isEnabled,
                        onChanged: merchantMode.isLoading
                            ? null
                            : (on) {
                                final notifier = ref.read(merchantModeProvider.notifier);
                                if (on) {
                                  notifier.enable();
                                } else {
                                  notifier.disable();
                                }
                              },
                      ),
                    ],
                  ),
                  Text(
                    merchantMode.isLoading
                        ? 'Enabling…'
                        : isEnabled
                            ? 'Enabled — accept payments'
                            : 'Turn on to accept payments',
                    style: AppTypography.textTheme.bodySmall,
                  ),
                  if (merchantMode.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.s),
                      child: Text(
                        'Could not enable Merchant Mode: ${merchantMode.error}',
                        key: const Key('merchant-mode-error'),
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  if (isEnabled)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.base),
                      child: SecondaryButton(
                        key: const Key('open-merchant-dashboard'),
                        label: 'Open Merchant Dashboard',
                        icon: Symbols.dashboard_rounded,
                        onPressed: () => Navigator.of(context).push(sharedAxisRoute(const MerchantDashboardScreen())),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Recent activity', style: AppTypography.textTheme.labelLarge),
          const EmptyState(
            icon: Symbols.receipt_long_rounded,
            title: 'No transactions yet',
            message: 'Payments you send or receive will show up here.',
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final Key? actionKey;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _QuickAction({this.actionKey, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      key: actionKey,
      onTap: onTap,
      borderRadius: AppRadius.lgRadius,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.lgRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(height: AppSpacing.s),
              Text(label, style: AppTypography.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
