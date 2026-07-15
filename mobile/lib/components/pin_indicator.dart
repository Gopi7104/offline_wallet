import 'package:flutter/material.dart';
import 'package:offline_wallet/theme/theme.dart';

/// Row of animated dots showing PIN-entry progress. Exposes [shake] via a
/// `GlobalKey<PinIndicatorState>` for a parent to trigger on a wrong PIN.
class PinIndicator extends StatefulWidget {
  final int length;
  final int filled;
  const PinIndicator({super.key, required this.length, required this.filled});

  @override
  State<PinIndicator> createState() => PinIndicatorState();
}

class PinIndicatorState extends State<PinIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _shakeAnimation =
      Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn));

  void shake() {
    _shakeController.forward(from: 0);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final offset = (1 - _shakeAnimation.value) * 10 * ((_shakeAnimation.value * 10).floor().isEven ? 1 : -1);
        return Transform.translate(offset: Offset(_shakeController.isAnimating ? offset : 0, 0), child: child);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.length, (i) {
          final isFilled = i < widget.filled;
          return AnimatedContainer(
            duration: AppMotion.fast,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFilled ? AppColors.primary : Colors.transparent,
              border: Border.all(color: isFilled ? AppColors.primary : AppColors.border, width: 1.5),
            ),
          );
        }),
      ),
    );
  }
}
