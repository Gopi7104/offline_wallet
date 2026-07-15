import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'auth_service.dart';

/// Real Firebase Authentication (Task 6.5, Email+Password). Constructed only
/// when `Firebase.initializeApp()` succeeded — see `auth_provider.dart`.
///
/// Google/Apple sign-in throw `AuthNotConfiguredException`: no Firebase
/// project is wired for this build (no `google-services.json` /
/// `GoogleService-Info.plist`), and `google_sign_in` isn't a dependency here
/// by design (see Task 6.5 plan — avoids extra native surface on demo day).
/// TODO(auth): once a real Firebase project exists, add `google_sign_in`,
/// implement `signInWithGoogle` against it, and wire native Apple Sign-In
/// entitlements for `signInWithApple`.
class FirebaseAuthService implements AuthService {
  final fb.FirebaseAuth _auth;

  FirebaseAuthService({fb.FirebaseAuth? auth}) : _auth = auth ?? fb.FirebaseAuth.instance;

  @override
  Stream<AppUser?> authStateChanges() {
    return _auth.authStateChanges().map((u) => u == null ? null : _toAppUser(u));
  }

  @override
  AppUser? get currentUser {
    final u = _auth.currentUser;
    return u == null ? null : _toAppUser(u);
  }

  @override
  Future<AppUser> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return _toAppUser(credential.user!);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(e.code, _friendlyMessage(e));
    }
  }

  @override
  Future<AppUser> registerWithEmail(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      return _toAppUser(credential.user!);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(e.code, _friendlyMessage(e));
    }
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    throw const AuthNotConfiguredException(
      'Google Sign-In needs a configured Firebase project. Run `flutterfire configure` and add google_sign_in.',
    );
  }

  @override
  Future<AppUser> signInWithApple() async {
    throw const AuthNotConfiguredException(
      'Apple Sign-In needs Sign in with Apple entitlements configured for this app.',
    );
  }

  @override
  Future<AppUser> continueAsGuest() async {
    // Deliberately local, not Firebase anonymous auth — guest mode must work
    // even when the Firebase project has anonymous sign-in disabled/unset.
    return AppUser(uid: 'guest-${DateTime.now().microsecondsSinceEpoch}', isGuest: true);
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  AppUser _toAppUser(fb.User u) =>
      AppUser(uid: u.uid, email: u.email, displayName: u.displayName);

  String _friendlyMessage(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Choose a stronger password (6+ characters).';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'api-key-not-valid.-please-pass-a-valid-api-key.':
      case 'invalid-api-key':
        return 'Firebase is not configured for this build yet.';
      case 'network-request-failed':
        return 'No network connection.';
      default:
        return e.message ?? 'Sign-in failed (${e.code}).';
    }
  }
}
