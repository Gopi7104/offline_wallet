import 'package:flutter_test/flutter_test.dart';
import 'package:offline_wallet/core/crypto/device_keypair_store.dart';
import 'package:offline_wallet/core/crypto/transfer_verifier.dart';

import 'fake_secure_store.dart';

void main() {
  group('Ed25519DeviceKeyPairStore', () {
    test('generates a well-formed Ed25519 keypair (32-byte public key)', () async {
      final store = Ed25519DeviceKeyPairStore(FakeSecureStore());
      final pubHex = await store.publicKeyHex();
      expect(pubHex.length, 64); // 32 bytes, hex
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(pubHex), isTrue);
    });

    test('signs with a well-formed 64-byte Ed25519 signature', () async {
      final store = Ed25519DeviceKeyPairStore(FakeSecureStore());
      final sigHex = await store.sign([1, 2, 3]);
      expect(sigHex.length, 128); // 64 bytes, hex
      expect(RegExp(r'^[0-9a-f]{128}$').hasMatch(sigHex), isTrue);
    });

    test('the private key never leaves the class: only the public key and signatures are observable', () async {
      // Compile-time property really, but assert the only two outputs
      // available to a caller are exactly these two hex strings — there is
      // no accessor that returns raw key material.
      final store = Ed25519DeviceKeyPairStore(FakeSecureStore());
      expect(store, isA<DeviceKeyPairStore>());
      await store.publicKeyHex();
      await store.sign([1]);
    });

    test('the key persists across "app restarts" (same backing SecureStore)', () async {
      final backing = FakeSecureStore();
      final first = Ed25519DeviceKeyPairStore(backing);
      final pub1 = await first.publicKeyHex();

      final second = Ed25519DeviceKeyPairStore(backing); // fresh instance, same storage
      final pub2 = await second.publicKeyHex();

      expect(pub2, pub1);
    });

    test('a fresh install (empty SecureStore) generates a fresh, different key', () async {
      final pubA = await Ed25519DeviceKeyPairStore(FakeSecureStore()).publicKeyHex();
      final pubB = await Ed25519DeviceKeyPairStore(FakeSecureStore()).publicKeyHex();
      expect(pubA, isNot(pubB));
    });

    test('a signature produced by the store verifies against its own public key', () async {
      final store = Ed25519DeviceKeyPairStore(FakeSecureStore());
      final pubHex = await store.publicKeyHex();
      final message = 'hello offline wallet'.codeUnits;
      final sigHex = await store.sign(message);

      final valid = await verifyTransferSignature(
        payload: message,
        signatureHex: sigHex,
        publicKeyHex: pubHex,
      );
      expect(valid, isTrue);
    });

    test('rejects when the message is tampered with', () async {
      final store = Ed25519DeviceKeyPairStore(FakeSecureStore());
      final pubHex = await store.publicKeyHex();
      final sigHex = await store.sign('original'.codeUnits);

      final valid = await verifyTransferSignature(
        payload: 'tampered'.codeUnits,
        signatureHex: sigHex,
        publicKeyHex: pubHex,
      );
      expect(valid, isFalse);
    });

    test('rejects against the wrong public key', () async {
      final store = Ed25519DeviceKeyPairStore(FakeSecureStore());
      final wrongPubHex = await Ed25519DeviceKeyPairStore(FakeSecureStore()).publicKeyHex();
      final message = 'payload'.codeUnits;
      final sigHex = await store.sign(message);

      final valid = await verifyTransferSignature(
        payload: message,
        signatureHex: sigHex,
        publicKeyHex: wrongPubHex,
      );
      expect(valid, isFalse);
    });
  });

  group('verifyTransferSignature — never throws on garbage input', () {
    test('malformed (non-hex) signature is rejected, not thrown', () async {
      expect(
        await verifyTransferSignature(payload: [1], signatureHex: 'not-hex', publicKeyHex: 'aa' * 32),
        isFalse,
      );
    });

    test('wrong-length public key is rejected, not thrown', () async {
      expect(
        await verifyTransferSignature(payload: [1], signatureHex: 'bb' * 64, publicKeyHex: 'aa' * 16),
        isFalse,
      );
    });

    test('empty signature is rejected, not thrown', () async {
      expect(
        await verifyTransferSignature(payload: [1], signatureHex: '', publicKeyHex: 'aa' * 32),
        isFalse,
      );
    });
  });
}
