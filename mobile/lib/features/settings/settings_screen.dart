import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:offline_wallet/components/components.dart';
import 'package:offline_wallet/features/auth/auth_provider.dart';
import 'package:offline_wallet/features/auth/auth_screen.dart';
import 'package:offline_wallet/features/security/pin_setup_screen.dart';
import 'package:offline_wallet/features/security/security_provider.dart';
import 'package:offline_wallet/theme/theme.dart';

/// Settings (Task 6.5): profile, security (PIN/biometrics), theme, about,
/// logout.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _changePin(BuildContext context) {
    return Navigator.of(context).push(
      sharedAxisRoute(PinSetupScreen(onComplete: () => Navigator.of(context).pop())),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Log out?',
      message: "You'll need to sign in again to use the wallet.",
      confirmLabel: 'Log out',
      danger: true,
    );
    if (!confirmed) return;
    await ref.read(authControllerProvider.notifier).signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(sharedAxisRoute(const AuthScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider).valueOrNull;
    final user = authState?.user;
    final biometricsAvailable = ref.watch(biometricsAvailableProvider).valueOrNull ?? false;
    final biometricsEnabled = ref.watch(biometricsEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.base),
        children: [
          _SectionCard(
            title: 'Profile',
            children: [
              _Row(
                icon: Symbols.account_circle_rounded,
                title: user?.isGuest == true ? 'Guest' : (user?.email ?? 'Signed out'),
                subtitle: user?.isGuest == true ? 'Developer Preview — data stays on this device' : 'Signed in',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          _SectionCard(
            title: 'Security',
            children: [
              _Row(
                icon: Symbols.pin_rounded,
                title: 'Change PIN',
                onTap: () => _changePin(context),
                trailing: const Icon(Symbols.chevron_right_rounded, color: AppColors.textMuted),
              ),
              const Divider(),
              _Row(
                icon: Symbols.fingerprint_rounded,
                title: 'Biometric payment confirmation',
                subtitle: biometricsAvailable ? null : 'Not available on this device',
                trailing: Switch(
                  key: const Key('settings-biometrics-toggle'),
                  value: biometricsEnabled && biometricsAvailable,
                  onChanged: biometricsAvailable
                      ? (v) => ref.read(biometricsEnabledProvider.notifier).setEnabled(v)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          const _SectionCard(
            title: 'Theme',
            children: [
              _Row(
                icon: Symbols.dark_mode_rounded,
                title: 'Dark',
                subtitle: 'More themes coming soon',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          const _SectionCard(
            title: 'About',
            children: [
              _Row(icon: Symbols.info_rounded, title: 'Offline Digital Cash Wallet', subtitle: 'v1.1 — research prototype'),
              Divider(),
              _Row(
                icon: Symbols.warning_rounded,
                title: 'No real money moves in this build',
                subtitle: 'Simulated bank + issuance for demonstration purposes only',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SecondaryButton(
            label: 'Log out',
            icon: Symbols.logout_rounded,
            onPressed: () => _logout(context, ref),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.s),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _Row({required this.icon, required this.title, this.subtitle, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 22),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.textTheme.bodyLarge),
                  if (subtitle != null)
                    Text(subtitle!, style: AppTypography.textTheme.bodySmall),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
