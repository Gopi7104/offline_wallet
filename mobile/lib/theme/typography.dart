import 'package:flutter/material.dart';
import 'colors.dart';

/// Type scale (Task 6.5 design system). Built on the platform default font
/// (no bundled webfont — this is an *offline* wallet, so typography leans on
/// weight/spacing/hierarchy rather than a network font dependency).
abstract final class AppTypography {
  static const String _family = 'Roboto';

  static TextTheme get textTheme => TextTheme(
        displayLarge: TextStyle(
          fontFamily: _family,
          fontSize: 40,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: AppColors.textPrimary,
          height: 1.1,
        ),
        displayMedium: TextStyle(
          fontFamily: _family,
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: AppColors.textPrimary,
          height: 1.15,
        ),
        headlineMedium: TextStyle(
          fontFamily: _family,
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          height: 1.2,
        ),
        headlineSmall: TextStyle(
          fontFamily: _family,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          height: 1.25,
        ),
        titleLarge: TextStyle(
          fontFamily: _family,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontFamily: _family,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontFamily: _family,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          fontFamily: _family,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          fontFamily: _family,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.textMuted,
        ),
        labelLarge: TextStyle(
          fontFamily: _family,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.2,
        ),
      );

  /// Bespoke style for the hero wallet balance — bigger than any named
  /// Material3 slot, tabular figures so the digits don't jitter as they
  /// count up.
  static TextStyle get balanceLarge => const TextStyle(
        fontFamily: _family,
        fontSize: 44,
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
        height: 1.05,
        fontFeatures: [FontFeature.tabularFigures()],
      ).copyWith(color: AppColors.textPrimary);

  static TextStyle get balanceMedium => const TextStyle(
        fontFamily: _family,
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        fontFeatures: [FontFeature.tabularFigures()],
      ).copyWith(color: AppColors.textPrimary);
}
