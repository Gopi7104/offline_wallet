import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:offline_wallet/theme/theme.dart';

/// 0-9 + backspace numeric keypad for PIN entry.
class PinKeyboard extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;

  const PinKeyboard({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
  });

  static const _layout = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', 'backspace'],
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _layout
              .map((row) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: row.map(_buildKey).toList(),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildKey(String key) {
    if (key.isEmpty) return const SizedBox(width: 72, height: 72);
    if (key == 'backspace') {
      return _KeyButton(onTap: onBackspace, child: Icon(Symbols.backspace_rounded, color: AppColors.textPrimary));
    }
    return _KeyButton(
      onTap: () => onDigit(key),
      child: Text(key, style: TextStyle(color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.w600)),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _KeyButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(width: 72, height: 72, child: Center(child: child)),
      ),
    );
  }
}
