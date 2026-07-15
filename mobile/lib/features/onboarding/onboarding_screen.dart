import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:offline_wallet/components/components.dart';
import 'package:offline_wallet/features/auth/auth_screen.dart';
import 'package:offline_wallet/theme/theme.dart';
import 'onboarding_provider.dart';

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  const _OnboardingPage({required this.icon, required this.title, required this.description});
}

const _pages = [
  _OnboardingPage(
    icon: Symbols.wifi_off_rounded,
    title: 'Offline Payments',
    description: 'Pay and get paid even without internet, banking, or cellular access.',
  ),
  _OnboardingPage(
    icon: Symbols.payments_rounded,
    title: 'Digital Cash',
    description: 'Your balance is signed digital tokens — cryptographically final the moment you pay.',
  ),
  _OnboardingPage(
    icon: Symbols.storefront_rounded,
    title: 'Merchant Payments',
    description: 'Flip into Merchant Mode to accept payments with a QR code — no separate registration.',
  ),
];

/// Three-page onboarding (Task 6.5): Skip/Next/Get Started, shown once.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(duration: AppMotion.base, curve: AppMotion.enter);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await ref.read(onboardingSeenProvider.notifier).markSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(sharedAxisRoute(const AuthScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: TextButton(
                  key: const Key('onboarding-skip'),
                  onPressed: _finish,
                  child: const Text('Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _OnboardingPageView(page: _pages[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: AppMotion.fast,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.pillRadius,
                    color: i == _page ? AppColors.primary : AppColors.border,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: PrimaryButton(
                key: const Key('onboarding-next'),
                label: isLast ? 'Get Started' : 'Next',
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageView extends StatelessWidget {
  final _OnboardingPage page;
  const _OnboardingPageView({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: AppColors.balanceGradient),
            ),
            child: Icon(page.icon, size: 64, color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          Text(page.title, style: AppTypography.textTheme.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.base),
          Text(page.description, style: AppTypography.textTheme.bodyLarge, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
