import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:offline_wallet/components/components.dart';
import 'package:offline_wallet/features/auth/auth_provider.dart';
import 'package:offline_wallet/features/auth/auth_screen.dart';
import 'package:offline_wallet/features/security/pin_setup_screen.dart';
import 'package:offline_wallet/features/security/security_provider.dart';
import 'package:offline_wallet/features/settings/theme_provider.dart';
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
                trailing: Icon(Symbols.chevron_right_rounded, color: AppColors.textMuted),
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
          _SectionCard(
            title: 'Appearance',
            children: [
              _ThemeModeSelector(
                selected: ref.watch(themeModeProvider),
                onChanged: (m) => ref.read(themeModeProvider.notifier).setMode(m),
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

/// Premium Appearance picker: three tappable cards (System / Light / Dark),
/// each showing a live mini-mock of the theme it selects, with a selected ring
/// in the brand color. Switching is instant and animated app-wide.
class _ThemeModeSelector extends StatelessWidget {
  final ThemeMode selected;
  final ValueChanged<ThemeMode> onChanged;
  const _ThemeModeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _ThemeOptionCard(
                optionKey: const Key('theme-option-system'),
                label: 'System',
                icon: Symbols.brightness_auto_rounded,
                selected: selected == ThemeMode.system,
                preview: const _SystemPreview(),
                onTap: () => onChanged(ThemeMode.system),
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: _ThemeOptionCard(
                optionKey: const Key('theme-option-light'),
                label: 'Light',
                icon: Symbols.light_mode_rounded,
                selected: selected == ThemeMode.light,
                preview: const _MiniThemePreview(brightness: Brightness.light),
                onTap: () => onChanged(ThemeMode.light),
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: _ThemeOptionCard(
                optionKey: const Key('theme-option-dark'),
                label: 'Dark',
                icon: Symbols.dark_mode_rounded,
                selected: selected == ThemeMode.dark,
                preview: const _MiniThemePreview(brightness: Brightness.dark),
                onTap: () => onChanged(ThemeMode.dark),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s),
        Text(
          switch (selected) {
            ThemeMode.system => 'Following your device appearance.',
            ThemeMode.light => 'Light theme is on.',
            ThemeMode.dark => 'Dark theme is on.',
          },
          style: AppTypography.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  final Key optionKey;
  final String label;
  final IconData icon;
  final bool selected;
  final Widget preview;
  final VoidCallback onTap;

  const _ThemeOptionCard({
    required this.optionKey,
    required this.label,
    required this.icon,
    required this.selected,
    required this.preview,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.primary;
    return InkWell(
      key: optionKey,
      onTap: onTap,
      borderRadius: AppRadius.lgRadius,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.enter,
        padding: const EdgeInsets.all(AppSpacing.s),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.08) : AppColors.surfaceRaised,
          borderRadius: AppRadius.lgRadius,
          border: Border.all(
            color: selected ? accent : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            preview,
            const SizedBox(height: AppSpacing.s),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: selected ? accent : AppColors.textSecondary),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.textTheme.labelLarge?.copyWith(
                      color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(Symbols.check_circle_rounded, size: 16, color: accent),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A tiny mock of a wallet screen (canvas → card → emerald balance bar) drawn
/// in the target [brightness], so the option shows exactly what it selects.
class _MiniThemePreview extends StatelessWidget {
  final Brightness brightness;
  const _MiniThemePreview({required this.brightness});

  bool get _light => brightness == Brightness.light;
  Color get _bg => _light ? const Color(0xFFF4F6FB) : const Color(0xFF0B1220);
  Color get _line => _light ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
  Color get _border => _light ? const Color(0xFFE2E8F0) : const Color(0xFF1F2937);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _bar(width: 30, color: _line),
          _bar(width: 18, color: _line.withValues(alpha: 0.6)),
          Container(
            height: 10,
            width: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppColors.primaryButtonGradient),
              borderRadius: AppRadius.pillRadius,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar({required double width, required Color color}) => Container(
        height: 5,
        width: width,
        decoration: BoxDecoration(color: color, borderRadius: AppRadius.pillRadius),
      );
}

/// System option preview: light and dark mocks split down the middle.
class _SystemPreview extends StatelessWidget {
  const _SystemPreview();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ClipRRect(
        borderRadius: AppRadius.mdRadius,
        child: Row(
          children: [
            Expanded(
              child: ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.5,
                  child: SizedBox(
                    width: MediaQuery.sizeOf(context).width,
                    child: const _MiniThemePreview(brightness: Brightness.light),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ClipRect(
                child: Align(
                  alignment: Alignment.centerRight,
                  widthFactor: 0.5,
                  child: SizedBox(
                    width: MediaQuery.sizeOf(context).width,
                    child: const _MiniThemePreview(brightness: Brightness.dark),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
