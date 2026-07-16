import 'package:flutter_test/flutter_test.dart';
import 'package:offline_wallet/core/secure_storage.dart';
import 'package:offline_wallet/features/security/pin_service.dart';

/// In-memory fake so PIN hashing/storage is testable without a platform
/// channel (mirrors the `FakeWalletRepository`-style fakes elsewhere).
class InMemorySecureStore implements SecureStore {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

void main() {
  group('PinService', () {
    test('no PIN set initially', () async {
      final service = PinService(storage: InMemorySecureStore());
      expect(await service.isPinSet(), false);
      expect(await service.verifyPin('123456'), false);
    });

    test('set then verify the same PIN succeeds', () async {
      final service = PinService(storage: InMemorySecureStore());
      await service.setPin('483920');
      expect(await service.isPinSet(), true);
      expect(await service.verifyPin('483920'), true);
    });

    test('wrong PIN is rejected', () async {
      final service = PinService(storage: InMemorySecureStore());
      await service.setPin('111111');
      expect(await service.verifyPin('222222'), false);
    });

    test('never stores the plaintext PIN', () async {
      final store = InMemorySecureStore();
      final service = PinService(storage: store);
      await service.setPin('999999');
      for (final value in store._values.values) {
        expect(value, isNot(contains('999999')));
      }
    });

    test('setPin overwrites a previous PIN', () async {
      final service = PinService(storage: InMemorySecureStore());
      await service.setPin('111111');
      await service.setPin('222222');
      expect(await service.verifyPin('111111'), false);
      expect(await service.verifyPin('222222'), true);
    });

    test('clearPin removes the stored PIN', () async {
      final service = PinService(storage: InMemorySecureStore());
      await service.setPin('483920');
      await service.clearPin();
      expect(await service.isPinSet(), false);
    });
  });
}
