import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_wallet/core/crypto/device_keypair_store.dart';
import 'package:offline_wallet/core/secure_storage.dart';
import 'package:offline_wallet/data/device_api_client.dart';
import 'package:offline_wallet/features/identity/device_registration_provider.dart';

import 'fake_secure_store.dart';

class _FakeDeviceApiClient implements DeviceApiClient {
  final List<String> registeredDeviceIds = [];
  final List<String> touchedDeviceIds = [];
  final List<String> registeredPublicKeys = [];
  Object? failWith;

  @override
  Future<DeviceResponse> register({
    required String deviceId,
    required String platform,
    required String deviceModel,
    required String appVersion,
    required String publicKeyHex,
  }) async {
    if (failWith != null) throw failWith!;
    registeredDeviceIds.add(deviceId);
    registeredPublicKeys.add(publicKeyHex);
    return DeviceResponse(deviceId: deviceId, accountId: 'acct-1', active: true);
  }

  @override
  Future<DeviceResponse> touchLastSeen(String deviceId) async {
    if (failWith != null) throw failWith!;
    touchedDeviceIds.add(deviceId);
    return DeviceResponse(deviceId: deviceId, accountId: 'acct-1', active: true);
  }
}

void main() {
  late FakeSecureStore store;
  late _FakeDeviceApiClient api;
  late ProviderContainer container;

  setUp(() {
    store = FakeSecureStore();
    api = _FakeDeviceApiClient();
    container = ProviderContainer(overrides: [
      appSecureStorageProvider.overrideWithValue(store),
      deviceApiClientProvider.overrideWithValue(api),
    ]);
  });
  tearDown(() => container.dispose());

  test('first run: registers the device (uploading its public key), never touches last-seen', () async {
    await container.read(deviceRegistrationProvider.future);

    expect(api.registeredDeviceIds, hasLength(1));
    expect(api.touchedDeviceIds, isEmpty);
    final expectedPubKey = await container.read(deviceKeyPairStoreProvider).publicKeyHex();
    expect(api.registeredPublicKeys.single, expectedPubKey);
  });

  test('subsequent runs (already registered): touches last-seen, never re-registers', () async {
    await container.read(deviceRegistrationProvider.future);
    expect(api.registeredDeviceIds, hasLength(1));

    // Simulate a fresh app session: a new container reading the same
    // persisted secure storage (the "registered" flag + deviceId survive).
    final container2 = ProviderContainer(overrides: [
      appSecureStorageProvider.overrideWithValue(store),
      deviceApiClientProvider.overrideWithValue(api),
    ]);
    addTearDown(container2.dispose);

    await container2.read(deviceRegistrationProvider.future);
    expect(api.registeredDeviceIds, hasLength(1)); // still just the one registration
    expect(api.touchedDeviceIds, hasLength(1));
  });

  test('the same local deviceId is reused across app sessions', () async {
    await container.read(deviceRegistrationProvider.future);
    final firstDeviceId = api.registeredDeviceIds.single;

    final container2 = ProviderContainer(overrides: [
      appSecureStorageProvider.overrideWithValue(store),
      deviceApiClientProvider.overrideWithValue(api),
    ]);
    addTearDown(container2.dispose);
    await container2.read(deviceRegistrationProvider.future);

    expect(api.touchedDeviceIds.single, firstDeviceId);
  });

  test('a fresh install (empty secure storage) gets its own new deviceId', () async {
    await container.read(deviceRegistrationProvider.future);
    final firstDeviceId = api.registeredDeviceIds.single;

    final container2 = ProviderContainer(overrides: [
      appSecureStorageProvider.overrideWithValue(FakeSecureStore()), // empty store
      deviceApiClientProvider.overrideWithValue(api),
    ]);
    addTearDown(container2.dispose);
    await container2.read(deviceRegistrationProvider.future);

    expect(api.registeredDeviceIds, hasLength(2));
    expect(api.registeredDeviceIds.last, isNot(firstDeviceId));
  });

  test('an unreachable backend is swallowed (offline-first): never throws', () async {
    api.failWith = Exception('network down');
    await expectLater(container.read(deviceRegistrationProvider.future), completes);
  });
}
