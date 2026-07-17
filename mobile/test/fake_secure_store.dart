import 'package:offline_wallet/core/secure_storage.dart';

/// In-memory [SecureStore] fake shared across tests that need to simulate
/// persistence (e.g. "same key/PIN across an app restart") without a real
/// platform channel. Mirrors the private fakes already duplicated in
/// token_wallet_test.dart / pin_service_test.dart.
class FakeSecureStore implements SecureStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);
}
