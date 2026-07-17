import 'package:cryptography/cryptography.dart';

import 'device_keypair_store.dart' show hexToBytes;

/// Stateless Ed25519 verification for an owner-signed Transfer (FR-PAY-04,
/// PAYMENT_PROTOCOL.md §6.4 step 4 "payer signature verifies over the
/// reconstructed TransferSigningPayload using payer_pubkey"). Used by the
/// merchant, fully offline: no keystore access, no network — it only checks
/// that [signatureHex] is a valid Ed25519 signature of [payload] under
/// [publicKeyHex]. Never throws: a malformed hex string or wrong-length key
/// is a `false`, the same as a cryptographically-invalid signature — the
/// merchant must treat attacker-supplied garbage uniformly.
Future<bool> verifyTransferSignature({
  required List<int> payload,
  required String signatureHex,
  required String publicKeyHex,
}) async {
  if (!_isHex(signatureHex, 128) || !_isHex(publicKeyHex, 64)) return false;
  try {
    final publicKey = SimplePublicKey(hexToBytes(publicKeyHex), type: KeyPairType.ed25519);
    final signature = Signature(hexToBytes(signatureHex), publicKey: publicKey);
    return await Ed25519().verify(payload, signature: signature);
  } catch (_) {
    return false;
  }
}

bool _isHex(String value, int expectedLength) =>
    value.length == expectedLength && RegExp(r'^[0-9a-fA-F]+$').hasMatch(value);
