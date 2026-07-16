import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:offline_wallet/core/secure_storage.dart';

/// PIN storage (Task 6.5, FR-adjacent security feature). The 6-digit PIN is
/// never stored in plaintext — only a salted SHA-256 hash, in the platform
/// secure storage (Android Keystore-backed / iOS Keychain-backed).
class PinService {
  static const _saltKey = 'pin_salt_v1';
  static const _hashKey = 'pin_hash_v1';

  final SecureStore _storage;

  PinService({SecureStore? storage}) : _storage = storage ?? FlutterSecureStore();

  Future<bool> isPinSet() async {
    final hash = await _storage.read(_hashKey);
    return hash != null && hash.isNotEmpty;
  }

  /// Hashes and stores [pin], replacing any existing one.
  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hash(pin, salt);
    await _storage.write(_saltKey, salt);
    await _storage.write(_hashKey, hash);
  }

  /// Verifies [pin] against the stored hash. Returns false if no PIN is set.
  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(_saltKey);
    final storedHash = await _storage.read(_hashKey);
    if (salt == null || storedHash == null) return false;
    return _hash(pin, salt) == storedHash;
  }

  Future<void> clearPin() async {
    await _storage.delete(_saltKey);
    await _storage.delete(_hashKey);
  }

  String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }
}
