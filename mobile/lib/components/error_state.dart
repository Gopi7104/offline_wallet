import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:offline_wallet/theme/theme.dart';
import 'secondary_button.dart';

/// Centered error placeholder with an optional retry action.
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl, horizontal: AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: const Icon(Symbols.error_outline_rounded, size: 32, color: AppColors.error),
          ),
          const SizedBox(height: AppSpacing.l),
          Text(message, style: AppTypography.textTheme.bodyMedium, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.l),
            SecondaryButton(label: 'Try again', onPressed: onRetry),
          ],
        ],
      ),
    );
  }
}
