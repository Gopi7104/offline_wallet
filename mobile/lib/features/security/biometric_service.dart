import 'package:local_auth/local_auth.dart';

/// Biometric authentication (Task 6.5). Deliberately `biometricOnly: true` —
/// on failure/unavailability the caller falls back to the app's own PIN
/// (never the OS lock screen), since the PIN is what "Create PIN" set up.
class BiometricService {
  final LocalAuthentication _localAuth;

  BiometricService({LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication();

  Future<bool> isAvailable() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  /// Prompts for a biometric and returns whether it succeeded. Never throws —
  /// any platform error (no enrolled biometric, lockout, cancelled) is treated
  /// as "not authenticated" so the caller can fall back to PIN.
  Future<bool> authenticate(String reason) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }
}
