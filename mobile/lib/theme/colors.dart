import 'package:flutter/material.dart';

/// Premium dark palette (Task 6.5 design system). A single fixed dark theme —
/// deliberately not a light/dark pair; fintech apps in this tier (Cash App,
/// CRED, Revolut) default to a dark, high-contrast surface.
abstract final class AppColors {
  // Base surfaces.
  static const Color background = Color(0xFF0B1220);
  static const Color surface = Color(0xFF111827);
  static const Color surfaceRaised = Color(0xFF161F2E);
  static const Color border = Color(0xFF1F2937);

  // Brand.
  static const Color primary = Color(0xFF10B981); // emerald
  static const Color primaryDim = Color(0xFF065F46);
  static const Color accent = Color(0xFF22D3EE); // cyan

  // Semantic.
  static const Color warning = Color(0xFFF59E0B); // amber
  static const Color success = Color(0xFF22C55E); // green
  static const Color error = Color(0xFFF43F5E); // modern red/rose

  // Text.
  static const Color textPrimary = Color(0xFFF9FAFB);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);

  // Gradients — hero cards, splash background, buttons.
  static const List<Color> heroGradient = [Color(0xFF0F2027), Color(0xFF10B981), Color(0xFF22D3EE)];
  static const List<Color> balanceGradient = [Color(0xFF064E3B), Color(0xFF10B981)];
  static const List<Color> splashGradient = [Color(0xFF0B1220), Color(0xFF0F2A22), Color(0xFF0B3B33)];
  static const List<Color> primaryButtonGradient = [Color(0xFF10B981), Color(0xFF22D3EE)];

  /// Frosted glass fill used by [GlassCard] — layered over gradients/images.
  static Color glassFill(double opacity) => Colors.white.withValues(alpha: opacity);
}
