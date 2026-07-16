import 'package:flutter/material.dart';

/// Premium adaptive palette (design system).
///
/// Two coordinated themes share one identity: the emerald→cyan brand and the
/// colored hero/balance gradients are **brightness-invariant** — a colored
/// card on a light or dark canvas is the signature of this tier (Cash App,
/// CRED, Revolut). Only the neutral **surface + text** tokens flip between the
/// deep-navy dark set and the soft cool-gray light set.
///
/// Surface/text tokens resolve against [brightness], which the app's
/// ThemeController keeps in lock-step with the active `MaterialApp` theme
/// (see `app/app.dart`). Brand tokens stay `const` so they remain usable in
/// `const` widgets.
abstract final class AppColors {
  /// Active brightness. Set once per frame by the root `builder` from
  /// `Theme.of(context).brightness`, so these getters always match the theme
  /// Flutter actually rendered. Defaults to dark (the app's original look).
  static Brightness brightness = Brightness.dark;

  static bool get _isLight => brightness == Brightness.light;

  // ── Brand (brightness-invariant) ─────────────────────────────────────────
  static const Color primary = Color(0xFF10B981); // emerald
  static const Color primaryDim = Color(0xFF065F46);
  static const Color accent = Color(0xFF06B6D4); // cyan (slightly deeper so it
  // stays legible as text/icon on white as well as on the dark canvas)

  // ── Semantic (brightness-invariant) ──────────────────────────────────────
  static const Color warning = Color(0xFFF59E0B); // amber
  static const Color success = Color(0xFF16A34A); // green
  static const Color error = Color(0xFFE11D48); // rose

  // ── Surfaces (brightness-aware) ──────────────────────────────────────────
  static const Color _backgroundDark = Color(0xFF0B1220);
  static const Color _backgroundLight = Color(0xFFF4F6FB);
  static Color get background => _isLight ? _backgroundLight : _backgroundDark;

  static const Color _surfaceDark = Color(0xFF111827);
  static const Color _surfaceLight = Color(0xFFFFFFFF);
  static Color get surface => _isLight ? _surfaceLight : _surfaceDark;

  static const Color _surfaceRaisedDark = Color(0xFF161F2E);
  static const Color _surfaceRaisedLight = Color(0xFFEDF1F7);
  static Color get surfaceRaised => _isLight ? _surfaceRaisedLight : _surfaceRaisedDark;

  static const Color _borderDark = Color(0xFF1F2937);
  static const Color _borderLight = Color(0xFFE2E8F0);
  static Color get border => _isLight ? _borderLight : _borderDark;

  // ── Text (brightness-aware) ──────────────────────────────────────────────
  static const Color _textPrimaryDark = Color(0xFFF9FAFB);
  static const Color _textPrimaryLight = Color(0xFF0B1220);
  static Color get textPrimary => _isLight ? _textPrimaryLight : _textPrimaryDark;

  static const Color _textSecondaryDark = Color(0xFF9CA3AF);
  static const Color _textSecondaryLight = Color(0xFF52606D);
  static Color get textSecondary => _isLight ? _textSecondaryLight : _textSecondaryDark;

  static const Color _textMutedDark = Color(0xFF6B7280);
  static const Color _textMutedLight = Color(0xFF94A3B8);
  static Color get textMuted => _isLight ? _textMutedLight : _textMutedDark;

  // ── Gradients — hero cards, splash, buttons (brightness-invariant) ───────
  static const List<Color> heroGradient = [Color(0xFF0F2027), Color(0xFF10B981), Color(0xFF22D3EE)];
  static const List<Color> balanceGradient = [Color(0xFF064E3B), Color(0xFF10B981)];
  static const List<Color> splashGradient = [Color(0xFF0B1220), Color(0xFF0F2A22), Color(0xFF0B3B33)];
  static const List<Color> primaryButtonGradient = [Color(0xFF10B981), Color(0xFF22D3EE)];

  /// Frosted glass fill used by [GlassCard] — layered over gradients/images.
  static Color glassFill(double opacity) => Colors.white.withValues(alpha: opacity);

  /// Text/icon color that reads well **on** the colored gradients (hero,
  /// balance, buttons) in either theme — those surfaces are always dark, so
  /// this stays light regardless of [brightness].
  static const Color onGradient = Color(0xFFFFFFFF);
  static const Color onGradientMuted = Color(0xB3FFFFFF); // white @ 70%
}
