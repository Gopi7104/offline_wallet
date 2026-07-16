import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:offline_wallet/app/home_screen.dart';
import 'package:offline_wallet/features/auth/auth_provider.dart';
import 'package:offline_wallet/features/auth/auth_screen.dart';
import 'package:offline_wallet/features/security/pin_setup_screen.dart';
import 'package:offline_wallet/features/security/security_provider.dart';
import 'package:offline_wallet/theme/theme.dart';
import 'onboarding_provider.dart';
import 'onboarding_screen.dart';

/// Splash (Task 6.5): animated logo + gradient background, doubles as the
/// loading state while onboarding/auth/PIN status resolve, then routes to
/// the right first screen. Entry point set in `app.dart`.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
  bool _minTimeElapsed = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Tied to the ticking AnimationController (frame-scheduled) rather than a
    // bare `Future.delayed` Timer, so `pumpAndSettle()` in widget tests waits
    // it out correctly instead of considering the tree "settled" early.
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _minTimeElapsed = true);
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _maybeNavigate({required bool onboardingSeen, required bool signedIn, required bool pinSet}) {
    if (_navigated || !_minTimeElapsed) return;
    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final Widget next;
      if (!onboardingSeen) {
        next = const OnboardingScreen();
      } else if (!signedIn) {
        next = const AuthScreen();
      } else if (!pinSet) {
        next = const PinSetupScreen();
      } else {
        next = const HomeScreen();
      }
      Navigator.of(context).pushReplacement(fadeThroughRoute(next));
    });
  }

  @override
  Widget build(BuildContext context) {
    final onboardingAsync = ref.watch(onboardingSeenProvider);
    final authAsync = ref.watch(authControllerProvider);
    final pinSetAsync = ref.watch(pinSetProvider);

    if (onboardingAsync.hasValue && authAsync.hasValue && pinSetAsync.hasValue) {
      _maybeNavigate(
        onboardingSeen: onboardingAsync.value!,
        signedIn: authAsync.value!.isSignedIn,
        pinSet: pinSetAsync.value!,
      );
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.splashGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: FadeTransition(
            // Entrance completes in the first ~35% of the splash's total
            // on-screen time, then holds — a snappy pop-in, not a slow fade.
            opacity: CurvedAnimation(parent: _controller, curve: const Interval(0, 0.35, curve: Curves.easeOut)),
            child: ScaleTransition(
              scale: CurvedAnimation(parent: _controller, curve: const Interval(0, 0.35, curve: Curves.easeOutBack)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: AppColors.primaryButtonGradient),
                    ),
                    child: const Icon(Symbols.bolt_rounded, size: 48, color: Colors.black),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text('Offline Wallet', style: AppTypography.textTheme.headlineMedium),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    'The Future of Offline Payments',
                    style: AppTypography.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
