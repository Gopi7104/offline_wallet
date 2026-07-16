import 'package:flutter/material.dart';
import 'package:offline_wallet/theme/theme.dart';

/// Centered placeholder for an empty list/section.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: AppColors.surfaceRaised, shape: BoxShape.circle),
            child: Icon(icon, size: 32, color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.l),
          Text(title, style: AppTypography.textTheme.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              message!,
              style: AppTypography.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: AppSpacing.l),
            action!,
          ],
        ],
      ),
    );
  }
}
