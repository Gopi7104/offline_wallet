import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_wallet/app/app.dart';
import 'package:offline_wallet/features/auth/auth_provider.dart';
import 'package:offline_wallet/features/onboarding/onboarding_provider.dart';
import 'package:offline_wallet/features/security/security_provider.dart';
import 'auth_session_test.dart' show FakeAuthService;
import 'pin_service_test.dart' show InMemorySecureStore;

/// Navigation guard (Splash → Onboarding/Auth/PIN/Home, Task 6.5): an
/// unauthenticated user must land on the Auth screen, not Home, regardless
/// of onboarding/PIN state.
void main() {
  testWidgets('unauthenticated session is redirected to the Auth screen, not Home', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingSeenProvider.overrideWith(
            (ref) => OnboardingSeenNotifier.seeded(InMemorySecureStore(), true),
          ),
          authControllerProvider.overrideWith(
            (ref) => AuthController.seeded(
              FakeAuthService(),
              InMemorySecureStore(),
              const AuthSessionState.unauthenticated(),
            ),
          ),
          pinSetProvider.overrideWith((ref) => Future.value(true)),
        ],
        child: const OfflineWalletApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth-email-field')), findsOneWidget);
    expect(find.byKey(const Key('auth-submit-button')), findsOneWidget);
    expect(find.text('Offline Wallet'), findsNothing);
  });
}
