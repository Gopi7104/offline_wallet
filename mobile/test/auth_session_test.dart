import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_wallet/features/auth/auth_provider.dart';
import 'package:offline_wallet/features/auth/auth_service.dart';
import 'pin_service_test.dart' show InMemorySecureStore;

/// Fake so guest/sign-in transitions are testable without Firebase.
class FakeAuthService implements AuthService {
  AppUser? _current;
  final _controller = const Stream<AppUser?>.empty();
  final bool failEmail;

  FakeAuthService({this.failEmail = false});

  @override
  Stream<AppUser?> authStateChanges() => _controller;

  @override
  AppUser? get currentUser => _current;

  @override
  Future<AppUser> continueAsGuest() async {
    _current = const AppUser(uid: 'guest-1', isGuest: true);
    return _current!;
  }

  @override
  Future<AppUser> registerWithEmail(String email, String password) => signInWithEmail(email, password);

  @override
  Future<AppUser> signInWithApple() async => throw const AuthNotConfiguredException('not configured');

  @override
  Future<AppUser> signInWithEmail(String email, String password) async {
    if (failEmail) throw const AuthException('wrong-password', 'Incorrect email or password.');
    _current = AppUser(uid: 'u-1', email: email);
    return _current!;
  }

  @override
  Future<AppUser> signInWithGoogle() async => throw const AuthNotConfiguredException('not configured');

  @override
  Future<void> signOut() async => _current = null;
}

void main() {
  group('AuthController', () {
    test('starts unauthenticated with no persisted session', () async {
      final controller = AuthController(FakeAuthService(), InMemorySecureStore());
      await Future<void>.delayed(Duration.zero);
      final state = controller.state.value!;
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.isSignedIn, false);
    });

    test('continueAsGuest transitions to guest and persists it', () async {
      final storage = InMemorySecureStore();
      final controller = AuthController(FakeAuthService(), storage);
      await Future<void>.delayed(Duration.zero);

      await controller.continueAsGuest();

      final state = controller.state.value!;
      expect(state.status, AuthStatus.guest);
      expect(state.user!.isGuest, true);
      expect(await storage.read('auth_session_status_v1'), 'guest');
    });

    test('successful email sign-in transitions to authenticated', () async {
      final controller = AuthController(FakeAuthService(), InMemorySecureStore());
      await Future<void>.delayed(Duration.zero);

      await controller.signInWithEmail('a@b.com', 'password1');

      final state = controller.state.value!;
      expect(state.status, AuthStatus.authenticated);
      expect(state.user!.email, 'a@b.com');
    });

    test('failed email sign-in surfaces the error, stays unauthenticated', () async {
      final controller = AuthController(FakeAuthService(failEmail: true), InMemorySecureStore());
      await Future<void>.delayed(Duration.zero);

      await controller.signInWithEmail('a@b.com', 'wrong');

      expect(controller.state.hasError, true);
    });

    test('signOut clears the session', () async {
      final storage = InMemorySecureStore();
      final controller = AuthController(FakeAuthService(), storage);
      await Future<void>.delayed(Duration.zero);
      await controller.continueAsGuest();

      await controller.signOut();

      expect(controller.state.value!.status, AuthStatus.unauthenticated);
      expect(await storage.read('auth_session_status_v1'), null);
    });

    test('seeded constructor skips restore for tests/previews', () {
      final controller = AuthController.seeded(
        FakeAuthService(),
        InMemorySecureStore(),
        const AuthSessionState(status: AuthStatus.guest, user: AppUser(uid: 'x', isGuest: true)),
      );
      expect(controller.state.value!.status, AuthStatus.guest);
    });
  });
}
