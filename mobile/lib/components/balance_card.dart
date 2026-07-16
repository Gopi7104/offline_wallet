import 'package:flutter/material.dart';
import 'package:offline_wallet/theme/theme.dart';

/// Gradient hero card for a headline number (wallet balance, etc). Decoupled
/// from any domain type — callers pass a raw numeric target + a formatter, so
/// this has no dependency on `core/money.dart`.
class BalanceCard extends StatelessWidget {
  final double targetValue;
  final String Function(double value) format;
  final String label;
  final String? subtitle;
  final List<Color>? gradientColors;
  final Widget? trailing;
  final Key? valueKey;

  const BalanceCard({
    super.key,
    required this.targetValue,
    required this.format,
    required this.label,
    this.subtitle,
    this.gradientColors,
    this.trailing,
    this.valueKey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: AppRadius.xlRadius,
        gradient: LinearGradient(
          colors: gradientColors ?? AppColors.balanceGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: targetValue),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Text(
              format(value),
              key: valueKey,
              style: AppTypography.balanceLarge.copyWith(color: Colors.white),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle!,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
