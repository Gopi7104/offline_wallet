import 'package:flutter/material.dart';
import 'package:offline_wallet/theme/theme.dart';

/// Branded loading indicator — a rotating gradient-swept ring, used on new
/// premium screens (existing tested screens keep their stock
/// `CircularProgressIndicator` under specific `Key`s — untouched).
class AnimatedLoading extends StatefulWidget {
  final double size;
  final Color? color;

  const AnimatedLoading({super.key, this.size = 48, this.color});

  @override
  State<AnimatedLoading> createState() => _AnimatedLoadingState();
}

class _AnimatedLoadingState extends State<AnimatedLoading> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _RingPainter(color: widget.color ?? AppColors.primary),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final Color color;
  const _RingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.1
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [color.withValues(alpha: 0), color],
        startAngle: 0,
        endAngle: 3.14159 * 1.6,
      ).createShader(rect);
    canvas.drawArc(rect.deflate(paint.strokeWidth / 2), 0, 3.14159 * 1.6, false, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => oldDelegate.color != color;
}
