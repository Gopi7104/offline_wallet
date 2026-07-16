import 'package:flutter/material.dart';
import 'package:offline_wallet/theme/theme.dart';

/// Full-width outlined button — secondary action, visually paired with
/// [PrimaryButton].
class SecondaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const SecondaryButton({super.key, required this.label, required this.onPressed, this.icon});

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> {
  double _scale = 1;

  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _enabled ? (_) => setState(() => _scale = 0.97) : null,
      onTapUp: _enabled ? (_) => setState(() => _scale = 1) : null,
      onTapCancel: _enabled ? () => setState(() => _scale = 1) : null,
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _scale,
        duration: AppMotion.fast,
        curve: AppMotion.enter,
        child: Opacity(
          opacity: _enabled ? 1 : 0.45,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: AppRadius.lgRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: AppColors.textPrimary, size: 20),
                      const SizedBox(width: AppSpacing.s),
                    ],
                    Flexible(
                      child: Text(
                        widget.label,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
