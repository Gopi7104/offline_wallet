import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_wallet/features/auth/auth_provider.dart';
import 'package:offline_wallet/features/auth/auth_service.dart';
import 'auth_session_test.dart' show FakeAuthService;
import 'pin_service_test.dart' show InMemorySecureStore;

/// identityHeadersProvider (FR-ID-01): the backend identity attached to
/// every API request. A real Firebase user sends its ID token; Guest Mode
/// (no Firebase session) falls back to the legacy x-account-id header.
void main() {
  test('a signed-in (non-guest) user sends an Authorization bearer header', () async {
    // identityHeadersProvider fetches the token from authServiceProvider (the
    // same service instance the real app wires into AuthController), so the
    // override must share one FakeAuthService — and it must actually have
    // signed in, since getIdToken() depends on the fake's internal state.
    final fakeService = FakeAuthService();
    final user = await fakeService.signInWithEmail('a@b.com', 'password1');
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(fakeService),
        authControllerProvider.overrideWith(
          (ref) => AuthController.seeded(
            fakeService,
            InMemorySecureStore(),
            AuthSessionState(status: AuthStatus.authenticated, user: user),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final headers = await container.read(identityHeadersProvider)();

    expect(headers['Authorization'], 'Bearer fake-id-token');
    expect(headers.containsKey('x-account-id'), false);
  });

  test('a guest session falls back to x-account-id keyed by the guest uid', () async {
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(
          (ref) => AuthController.seeded(
            FakeAuthService(),
            InMemorySecureStore(),
            const AuthSessionState(status: AuthStatus.guest, user: AppUser(uid: 'guest-42', isGuest: true)),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final headers = await container.read(identityHeadersProvider)();

    expect(headers['x-account-id'], 'guest-42');
    expect(headers.containsKey('Authorization'), false);
  });

  test('no session at all falls back to the fixed test account', () async {
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(
          (ref) => AuthController.seeded(
            FakeAuthService(),
            InMemorySecureStore(),
            const AuthSessionState.unauthenticated(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final headers = await container.read(identityHeadersProvider)();

    expect(headers['x-account-id'], 'test-account-1');
  });
}
