/// Auth feature domain (Task 6.5). `AppUser` is an auth-local value type —
/// deliberately not in `lib/domain/`, which is reserved for the wallet/coin
/// payment domain (ARCHITECTURE.md §6.1).
class AppUser {
  final String uid;
  final String? email;
  final String? displayName;
  final bool isGuest;

  const AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.isGuest = false,
  });

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.uid == uid &&
      other.email == email &&
      other.displayName == displayName &&
      other.isGuest == isGuest;

  @override
  int get hashCode => Object.hash(uid, email, displayName, isGuest);
}

/// Thrown by sign-in methods that need configuration this build doesn't have
/// (no Firebase project wired, no Google/Apple client IDs). The UI catches
/// this and shows a clear "not configured" notice — never a fake success.
class AuthNotConfiguredException implements Exception {
  final String message;
  const AuthNotConfiguredException(this.message);
  @override
  String toString() => message;
}

/// Thrown for a real, honest auth failure (wrong password, network error,
/// invalid/unconfigured API key, etc). Carries the provider's message as-is.
class AuthException implements Exception {
  final String code;
  final String message;
  const AuthException(this.code, this.message);
  @override
  String toString() => message;
}

/// Port for authentication (Task 6.5). Two implementations:
///   - `FirebaseAuthService` — real `firebase_auth` calls for Email+Password;
///     Google/Apple throw `AuthNotConfiguredException` (no project wired).
///   - `GuestOnlyAuthService` — used when Firebase failed to initialize at
///     all; Guest Mode must always work regardless of Firebase's state.
abstract interface class AuthService {
  Stream<AppUser?> authStateChanges();
  AppUser? get currentUser;
  Future<AppUser> signInWithEmail(String email, String password);
  Future<AppUser> registerWithEmail(String email, String password);
  Future<AppUser> signInWithGoogle();
  Future<AppUser> signInWithApple();
  Future<AppUser> continueAsGuest();
  Future<void> signOut();
}
