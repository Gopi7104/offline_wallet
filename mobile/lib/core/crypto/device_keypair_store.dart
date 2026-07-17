import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/core/secure_storage.dart';

/// Port: the device's Ed25519 keypair, proving ownership of offline
/// transfers (FR-PAY-04, FR-ID-02). Generated once per install; the private
/// key never leaves this class — only the public key and produced
/// signatures cross the boundary (never logged, never serialized whole).
abstract interface class DeviceKeyPairStore {
  /// The device's public key, hex-encoded (64 chars) — safe to transmit.
  Future<String> publicKeyHex();

  /// Sign [message] with the device private key. Returns a hex-encoded
  /// (128 chars) Ed25519 signature.
  Future<String> sign(List<int> message);
}

const String _kDevicePrivateKeySeedKey = 'device_ed25519_seed_v1';

/// Adapter: pure-Dart Ed25519 (`package:cryptography`). The private key is
/// persisted via the existing encrypted [SecureStore] — the same mechanism
/// this app already trusts for the PIN and auth session (Android Keystore-
/// backed / iOS Keychain-backed at rest). Generated once on first use and
/// reused across app restarts; a re-registration (e.g. reinstall, where
/// secure storage was wiped) generates a fresh key, matching FR-ID-04 "new
/// key on device re-registration".
class Ed25519DeviceKeyPairStore implements DeviceKeyPairStore {
  final SecureStore _store;
  final Ed25519 _algorithm = Ed25519();
  Future<SimpleKeyPair>? _pending;

  Ed25519DeviceKeyPairStore(this._store);

  Future<SimpleKeyPair> _keyPair() {
    return _pending ??= _loadOrCreate();
  }

  Future<SimpleKeyPair> _loadOrCreate() async {
    final storedHex = await _store.read(_kDevicePrivateKeySeedKey);
    if (storedHex != null) {
      return _algorithm.newKeyPairFromSeed(hexToBytes(storedHex));
    }
    final keyPair = await _algorithm.newKeyPair();
    final seed = await keyPair.extractPrivateKeyBytes();
    await _store.write(_kDevicePrivateKeySeedKey, bytesToHex(seed));
    return keyPair;
  }

  @override
  Future<String> publicKeyHex() async {
    final keyPair = await _keyPair();
    final publicKey = await keyPair.extractPublicKey();
    return bytesToHex(publicKey.bytes);
  }

  @override
  Future<String> sign(List<int> message) async {
    final keyPair = await _keyPair();
    final signature = await _algorithm.sign(message, keyPair: keyPair);
    return bytesToHex(signature.bytes);
  }
}

String bytesToHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

List<int> hexToBytes(String hex) {
  final result = <int>[];
  for (var i = 0; i + 1 < hex.length; i += 2) {
    result.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return result;
}

final deviceKeyPairStoreProvider = Provider<DeviceKeyPairStore>((ref) {
  final store = ref.watch(appSecureStorageProvider);
  return Ed25519DeviceKeyPairStore(store);
});
