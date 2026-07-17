import { ed25519 } from '@noble/curves/ed25519.js';

/**
 * Ed25519 primitives (shared crypto port). Wraps @noble/curves — an audited,
 * pure-JS, constant-time implementation — so the rest of the codebase never
 * imports the curve library directly. Used by Issuance (signing) and
 * Settlement (verification); neither owns the algorithm, both share it.
 */

export const ED25519_PRIVATE_KEY_BYTES = 32;
export const ED25519_PUBLIC_KEY_BYTES = 32;
export const ED25519_SIGNATURE_BYTES = 64;

export function derivePublicKey(privateKey: Uint8Array): Uint8Array {
  return ed25519.getPublicKey(privateKey);
}

export function signEd25519(privateKey: Uint8Array, message: Uint8Array): Uint8Array {
  return ed25519.sign(message, privateKey);
}

/**
 * Verify a signature. Never throws — a malformed signature or public key is
 * a failed verification, not an exception the caller must catch (settlement
 * must be able to treat "invalid" uniformly, including attacker-supplied
 * garbage). Uses the library's constant-time comparison internally.
 */
export function verifyEd25519(publicKey: Uint8Array, message: Uint8Array, signature: Uint8Array): boolean {
  try {
    return ed25519.verify(signature, message, publicKey);
  } catch {
    return false;
  }
}

export function hexToBytes(hex: string, expectedBytes: number, label: string): Uint8Array {
  if (!/^[0-9a-fA-F]+$/.test(hex) || hex.length !== expectedBytes * 2) {
    throw new Error(`${label} must be ${expectedBytes} bytes of hex (${expectedBytes * 2} hex chars)`);
  }
  return new Uint8Array(Buffer.from(hex, 'hex'));
}

export function bytesToHex(bytes: Uint8Array): string {
  return Buffer.from(bytes).toString('hex');
}
