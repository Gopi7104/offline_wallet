import { derivePublicKey, hexToBytes, ED25519_PRIVATE_KEY_BYTES } from '../shared/crypto/ed25519';

/**
 * Bank Issuer Ed25519 key management (ARCHITECTURE.md "Key Management": the
 * issuer key signs every coin; the private key never leaves the backend, only
 * the public key is ever exposed for verification). Mirrors the fail-fast /
 * dev-fallback / cached-singleton pattern of platform/firebase.ts.
 *
 * Credential resolution, in order:
 *   1. `ISSUER_PRIVATE_KEY_HEX` — 32-byte Ed25519 seed, hex-encoded. Required
 *      in production (KMS/HSM-backed secret injection in real deployments;
 *      here, an environment variable stands in for that).
 *   2. Neither set, and NODE_ENV !== 'production' — falls back to a FIXED,
 *      committed development seed. Fixed (not randomly generated at startup)
 *      so restarting the dev server doesn't invalidate every token already
 *      minted or in a wallet. Logged loudly; never for production.
 *   3. Neither set, and NODE_ENV === 'production' — fails fast (thrown at
 *      first use, i.e. before the server accepts traffic — see index.ts).
 */

// Dev-only seed. Not a secret — anyone can read this file — which is exactly
// why it must never be used in production; ISSUER_PRIVATE_KEY_HEX overrides it.
const DEV_ISSUER_PRIVATE_KEY_HEX = '20c824c4b02514893a45b1af136b50eb3c5b696aeb21ea6b2f2037a7d14cc6c2';

let cachedPrivateKey: Uint8Array | undefined;
let cachedPublicKey: Uint8Array | undefined;

function loadPrivateKey(): Uint8Array {
  if (cachedPrivateKey) return cachedPrivateKey;

  const isProduction = process.env.NODE_ENV === 'production';
  const hex = process.env.ISSUER_PRIVATE_KEY_HEX;

  if (hex) {
    cachedPrivateKey = hexToBytes(hex, ED25519_PRIVATE_KEY_BYTES, 'ISSUER_PRIVATE_KEY_HEX');
  } else if (!isProduction) {
    // eslint-disable-next-line no-console
    console.warn(
      '[issuer_keys] ISSUER_PRIVATE_KEY_HEX not set — signing with the fixed DEVELOPMENT ' +
        'issuer key. Tokens signed with this key are not authentic. Never run production like this.',
    );
    cachedPrivateKey = hexToBytes(DEV_ISSUER_PRIVATE_KEY_HEX, ED25519_PRIVATE_KEY_BYTES, 'DEV_ISSUER_PRIVATE_KEY_HEX');
  } else {
    throw new Error(
      'Issuer key material missing: set ISSUER_PRIVATE_KEY_HEX (32-byte Ed25519 seed, hex-encoded) ' +
        'before starting in production. A backend that cannot sign tokens authentically must not serve traffic.',
    );
  }

  return cachedPrivateKey;
}

/** The issuer's private signing key. Issuance-context use only. */
export function getIssuerPrivateKey(): Uint8Array {
  return loadPrivateKey();
}

/** The issuer's public verification key, derived from the private key. */
export function getIssuerPublicKey(): Uint8Array {
  if (!cachedPublicKey) {
    cachedPublicKey = derivePublicKey(loadPrivateKey());
  }
  return cachedPublicKey;
}
