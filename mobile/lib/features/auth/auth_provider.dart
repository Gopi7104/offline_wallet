import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/core/secure_storage.dart';
import 'auth_service.dart';
import 'firebase_auth_service.dart';
import 'guest_only_auth_service.dart';

/// Auth session state (Task 6.5).

enum AuthStatus { unauthenticated, guest, authenticated }

class AuthSessionState {
  final AuthStatus status;
  final AppUser? user;

  const AuthSessionState({required this.status, this.user});
  const AuthSessionState.unauthenticated() : status = AuthStatus.unauthenticated, user = null;

  bool get isSignedIn => status != AuthStatus.unauthenticated;
}

/// Whether `Firebase.initializeApp()` succeeded at bootstrap. Overridden in
/// `main.dart`; defaults to false so tests/uninitialized runs never attempt a
/// real Firebase call.
final firebaseReadyProvider = Provider<bool>((ref) => false);

final authServiceProvider = Provider<AuthService>((ref) {
  return ref.watch(firebaseReadyProvider) ? FirebaseAuthService() : GuestOnlyAuthService();
});

const _sessionStorageKey = 'auth_session_status_v1';

class AuthController extends StateNotifier<AsyncValue<AuthSessionState>> {
  final AuthService _service;
  final SecureStore _storage;

  AuthController(this._service, this._storage) : super(const AsyncValue.loading()) {
    _restore();
  }

  /// Test/preview seam: build a controller already sitting at [initialState],
  /// skipping the async storage read (mirrors `merchantModeProvider`'s
  /// override-with-a-fake-repository pattern used elsewhere in this codebase).
  AuthController.seeded(this._service, this._storage, AuthSessionState initialState)
      : super(AsyncValue.data(initialState));

  Future<void> _restore() async {
    final saved = await _storage.read(_sessionStorageKey);
    if (saved == 'guest') {
      state = AsyncValue.data(
        AuthSessionState(status: AuthStatus.guest, user: await _service.continueAsGuest()),
      );
    } else if (saved == 'authenticated' && _service.currentUser != null) {
      state = AsyncValue.data(AuthSessionState(status: AuthStatus.authenticated, user: _service.currentUser));
    } else {
      state = const AsyncValue.data(AuthSessionState.unauthenticated());
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _service.signInWithEmail(email, password);
      await _storage.write(_sessionStorageKey, 'authenticated');
      state = AsyncValue.data(AuthSessionState(status: AuthStatus.authenticated, user: user));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> register(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _service.registerWithEmail(email, password);
      await _storage.write(_sessionStorageKey, 'authenticated');
      state = AsyncValue.data(AuthSessionState(status: AuthStatus.authenticated, user: user));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final user = await _service.signInWithGoogle();
      await _storage.write(_sessionStorageKey, 'authenticated');
      state = AsyncValue.data(AuthSessionState(status: AuthStatus.authenticated, user: user));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signInWithApple() async {
    state = const AsyncValue.loading();
    try {
      final user = await _service.signInWithApple();
      await _storage.write(_sessionStorageKey, 'authenticated');
      state = AsyncValue.data(AuthSessionState(status: AuthStatus.authenticated, user: user));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> continueAsGuest() async {
    state = const AsyncValue.loading();
    try {
      final user = await _service.continueAsGuest();
      await _storage.write(_sessionStorageKey, 'guest');
      state = AsyncValue.data(AuthSessionState(status: AuthStatus.guest, user: user));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    await _service.signOut();
    await _storage.delete(_sessionStorageKey);
    state = const AsyncValue.data(AuthSessionState.unauthenticated());
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<AuthSessionState>>((ref) {
  return AuthController(ref.watch(authServiceProvider), ref.watch(appSecureStorageProvider));
});
