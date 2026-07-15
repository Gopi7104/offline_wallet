import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

/// Motion constants + reusable route builders (Task 6.5 design system).
/// Every `Navigator.push` in the app should go through [sharedAxisRoute] (or
/// [fadeScaleRoute] for modal-feeling pushes) instead of a bare
/// `MaterialPageRoute`, so transitions feel like one consistent system.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve spring = Curves.easeOutBack;
}

/// Horizontal shared-axis push — the default for forward navigation
/// (Material motion system, via the official `animations` package).
///
/// [settings] lets a caller name the route (e.g. so a deep multi-step flow
/// can `Navigator.popUntil(ModalRoute.withName(...))` back to it directly,
/// instead of popping one screen at a time).
Route<T> sharedAxisRoute<T>(Widget page, {RouteSettings? settings}) {
  return PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: AppMotion.base,
    reverseTransitionDuration: AppMotion.base,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        transitionType: SharedAxisTransitionType.horizontal,
        child: child,
      );
    },
  );
}

/// Fade-through — used for replacing the whole app shell (e.g. Splash →
/// Onboarding → Auth → Home) where a horizontal slide would feel wrong.
Route<T> fadeThroughRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: AppMotion.base,
    reverseTransitionDuration: AppMotion.base,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeThroughTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        child: child,
      );
    },
  );
}

/// Fade + scale — used for lightweight modal-feeling pushes (e.g. success/
/// confirmation screens).
Route<T> fadeScaleRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: AppMotion.base,
    reverseTransitionDuration: AppMotion.fast,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeScaleTransition(animation: animation, child: child);
    },
  );
}
