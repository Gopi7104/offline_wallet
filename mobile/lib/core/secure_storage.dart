import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Port for a simple encrypted key-value store (ports-and-adapters, per this
/// project's architecture). Abstracting over `FlutterSecureStorage` lets
/// PIN/auth/onboarding state be unit-tested with an in-memory fake instead of
/// requiring a platform channel.
abstract interface class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Adapter over `flutter_secure_storage` (Android Keystore-backed / iOS
/// Keychain-backed).
class FlutterSecureStore implements SecureStore {
  final FlutterSecureStorage _storage;

  FlutterSecureStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Shared secure-storage instance (Task 6.5): PIN hash, biometrics
/// preference, auth session flag, onboarding-seen flag all live here.
final appSecureStorageProvider = Provider<SecureStore>((ref) => FlutterSecureStore());
