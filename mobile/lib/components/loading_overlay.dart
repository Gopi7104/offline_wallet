import 'package:flutter/material.dart';
import 'package:offline_wallet/theme/theme.dart';
import 'animated_loading.dart';

/// Dims and blocks [child] with a centered [AnimatedLoading] while [visible].
///
/// Uses `AnimatedSwitcher` (not `AnimatedOpacity` over an always-mounted
/// child) so the spinner's perpetually-repeating `AnimationController` is
/// actually disposed when hidden — an always-mounted repeating animation
/// never lets `pumpAndSettle()` in widget tests settle, even while invisible.
class LoadingOverlay extends StatelessWidget {
  final bool visible;
  final Widget child;
  final String? message;

  const LoadingOverlay({super.key, required this.visible, required this.child, this.message});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !visible,
            child: AnimatedSwitcher(
              duration: AppMotion.base,
              child: visible
                  ? Container(
                      key: const ValueKey('loading-overlay-visible'),
                      color: Colors.black.withValues(alpha: 0.6),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AnimatedLoading(),
                          if (message != null) ...[
                            const SizedBox(height: AppSpacing.base),
                            Text(message!, style: const TextStyle(color: Colors.white)),
                          ],
                        ],
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('loading-overlay-hidden')),
            ),
          ),
        ),
      ],
    );
  }
}
