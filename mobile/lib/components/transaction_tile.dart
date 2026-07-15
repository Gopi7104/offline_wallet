import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:offline_wallet/theme/theme.dart';

/// List row for a recent transaction (load, payment, receipt). Renders
/// whatever `amountLabel` string it's given — sign/formatting is the
/// caller's job.
class TransactionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amountLabel;
  final bool isCredit;
  final IconData? icon;

  const TransactionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amountLabel,
    required this.isCredit,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final tint = isCredit ? AppColors.success : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: tint.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(
              icon ?? (isCredit ? Symbols.call_received_rounded : Symbols.call_made_rounded),
              color: tint,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTypography.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          Text(
            amountLabel,
            style: TextStyle(
              color: isCredit ? AppColors.success : AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
