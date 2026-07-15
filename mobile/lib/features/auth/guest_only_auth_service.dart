import 'dart:async';
import 'auth_service.dart';

/// Fallback used when `Firebase.initializeApp()` failed entirely at app
/// bootstrap (see `main.dart`). Guest Mode must always work regardless of
/// Firebase's state; every other method fails honestly rather than pretending
/// to reach a backend that isn't there.
class GuestOnlyAuthService implements AuthService {
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;

  @override
  Stream<AppUser?> authStateChanges() => _controller.stream;

  @override
  AppUser? get currentUser => _current;

  @override
  Future<AppUser> signInWithEmail(String email, String password) async {
    throw const AuthNotConfiguredException('Firebase is not configured for this build yet.');
  }

  @override
  Future<AppUser> registerWithEmail(String email, String password) async {
    throw const AuthNotConfiguredException('Firebase is not configured for this build yet.');
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    throw const AuthNotConfiguredException('Firebase is not configured for this build yet.');
  }

  @override
  Future<AppUser> signInWithApple() async {
    throw const AuthNotConfiguredException('Firebase is not configured for this build yet.');
  }

  @override
  Future<AppUser> continueAsGuest() async {
    final user = AppUser(uid: 'guest-${DateTime.now().microsecondsSinceEpoch}', isGuest: true);
    _current = user;
    _controller.add(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _controller.add(null);
  }
}
