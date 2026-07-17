import {
  derivePublicKey,
  signEd25519,
  verifyEd25519,
  hexToBytes,
  bytesToHex,
  ED25519_PRIVATE_KEY_BYTES,
  ED25519_SIGNATURE_BYTES,
} from '../src/shared/crypto/ed25519';
import { canonicalTokenPayload, toEpochSeconds, TokenSigningFields } from '../src/shared/crypto/token_canonical_payload';
import { getIssuerPrivateKey, getIssuerPublicKey } from '../src/platform/issuer_keys';
import { Ed25519TokenSigner } from '../src/modules/issuance/infra/ed25519_token_signer';
import { Ed25519TokenVerifier } from '../src/modules/settlement/infra/ed25519_token_verifier';

const FIELDS: TokenSigningFields = {
  tokenId: 'tok-abc-123',
  denominationPaise: 5000,
  ownerId: 'payer-1',
  issuedAtEpochSeconds: 1_700_000_000,
  expiryEpochSeconds: 1_702_592_000,
};

describe('Ed25519 primitives (shared/crypto/ed25519.ts)', () => {
  it('sign then verify round-trips true with the matching key pair', () => {
    const priv = hexToBytes('11'.repeat(ED25519_PRIVATE_KEY_BYTES), ED25519_PRIVATE_KEY_BYTES, 'test key');
    const pub = derivePublicKey(priv);
    const msg = new TextEncoder().encode('hello offline wallet');
    const sig = signEd25519(priv, msg);
    expect(sig.length).toBe(ED25519_SIGNATURE_BYTES);
    expect(verifyEd25519(pub, msg, sig)).toBe(true);
  });

  it('fails verification when the message is tampered with', () => {
    const priv = hexToBytes('22'.repeat(ED25519_PRIVATE_KEY_BYTES), ED25519_PRIVATE_KEY_BYTES, 'test key');
    const pub = derivePublicKey(priv);
    const sig = signEd25519(priv, new TextEncoder().encode('original'));
    expect(verifyEd25519(pub, new TextEncoder().encode('tampered'), sig)).toBe(false);
  });

  it('fails verification against the wrong public key', () => {
    const privA = hexToBytes('33'.repeat(ED25519_PRIVATE_KEY_BYTES), ED25519_PRIVATE_KEY_BYTES, 'key a');
    const privB = hexToBytes('44'.repeat(ED25519_PRIVATE_KEY_BYTES), ED25519_PRIVATE_KEY_BYTES, 'key b');
    const pubB = derivePublicKey(privB);
    const msg = new TextEncoder().encode('payload');
    const sig = signEd25519(privA, msg);
    expect(verifyEd25519(pubB, msg, sig)).toBe(false);
  });

  it('never throws on garbage signature bytes; returns false', () => {
    const priv = hexToBytes('55'.repeat(ED25519_PRIVATE_KEY_BYTES), ED25519_PRIVATE_KEY_BYTES, 'test key');
    const pub = derivePublicKey(priv);
    const msg = new TextEncoder().encode('payload');
    const garbage = new Uint8Array(3); // wrong length entirely
    expect(() => verifyEd25519(pub, msg, garbage)).not.toThrow();
    expect(verifyEd25519(pub, msg, garbage)).toBe(false);
  });

  it('hexToBytes rejects the wrong length or non-hex input', () => {
    expect(() => hexToBytes('abcd', 32, 'label')).toThrow(/label/);
    expect(() => hexToBytes('zz'.repeat(32), 32, 'label')).toThrow(/label/);
  });

  it('bytesToHex/hexToBytes round-trip', () => {
    const priv = hexToBytes('66'.repeat(32), 32, 'label');
    expect(hexToBytes(bytesToHex(priv), 32, 'label')).toEqual(priv);
  });
});

describe('Canonical token payload (shared/crypto/token_canonical_payload.ts)', () => {
  it('is deterministic for the same fields', () => {
    const a = canonicalTokenPayload(FIELDS);
    const b = canonicalTokenPayload({ ...FIELDS });
    expect(Buffer.from(a)).toEqual(Buffer.from(b));
  });

  it('changes when any single field changes', () => {
    const base = Buffer.from(canonicalTokenPayload(FIELDS)).toString('utf8');
    expect(Buffer.from(canonicalTokenPayload({ ...FIELDS, denominationPaise: 5001 })).toString('utf8')).not.toBe(base);
    expect(Buffer.from(canonicalTokenPayload({ ...FIELDS, ownerId: 'payer-2' })).toString('utf8')).not.toBe(base);
    expect(Buffer.from(canonicalTokenPayload({ ...FIELDS, tokenId: 'tok-other' })).toString('utf8')).not.toBe(base);
    expect(
      Buffer.from(canonicalTokenPayload({ ...FIELDS, issuedAtEpochSeconds: FIELDS.issuedAtEpochSeconds + 1 })).toString(
        'utf8',
      ),
    ).not.toBe(base);
    expect(
      Buffer.from(canonicalTokenPayload({ ...FIELDS, expiryEpochSeconds: FIELDS.expiryEpochSeconds + 1 })).toString(
        'utf8',
      ),
    ).not.toBe(base);
  });

  it('safely escapes owner ids containing quotes or braces (no injection into the payload shape)', () => {
    const tricky = canonicalTokenPayload({ ...FIELDS, ownerId: '"}{"tokenId":"evil' });
    // Round-trips through JSON.stringify's escaping — must remain parseable
    // as a single JSON object with the original ownerId preserved.
    const parsed = JSON.parse(Buffer.from(tricky).toString('utf8'));
    expect(parsed.ownerId).toBe('"}{"tokenId":"evil');
    expect(parsed.tokenId).toBe(FIELDS.tokenId);
  });

  it('toEpochSeconds converts a Date to whole seconds', () => {
    expect(toEpochSeconds(new Date(1_700_000_000_000))).toBe(1_700_000_000);
  });
});

describe('Issuer key management (platform/issuer_keys.ts)', () => {
  it('derives a consistent public key from the private key', () => {
    const priv = getIssuerPrivateKey();
    const pub = getIssuerPublicKey();
    expect(pub).toEqual(derivePublicKey(priv));
  });

  it('returns the same key material across calls (cached, not regenerated)', () => {
    expect(getIssuerPrivateKey()).toEqual(getIssuerPrivateKey());
    expect(getIssuerPublicKey()).toEqual(getIssuerPublicKey());
  });
});

describe('Ed25519TokenSigner + Ed25519TokenVerifier (issuance/settlement adapters)', () => {
  it('a signature produced by the signer verifies against the issuer public key', () => {
    const signer = new Ed25519TokenSigner();
    const verifier = new Ed25519TokenVerifier();
    const signature = signer.sign(FIELDS);
    expect(signature).toMatch(/^[0-9a-f]{128}$/);
    expect(verifier.verify(FIELDS, signature)).toBe(true);
  });

  it('rejects when any signed field is modified after signing', () => {
    const signer = new Ed25519TokenSigner();
    const verifier = new Ed25519TokenVerifier();
    const signature = signer.sign(FIELDS);
    expect(verifier.verify({ ...FIELDS, denominationPaise: FIELDS.denominationPaise + 100 }, signature)).toBe(false);
  });

  it('rejects a forged signature (well-formed hex, not produced by the issuer key)', () => {
    const verifier = new Ed25519TokenVerifier();
    const forged = 'ab'.repeat(ED25519_SIGNATURE_BYTES);
    expect(verifier.verify(FIELDS, forged)).toBe(false);
  });

  it('rejects a signature produced by a different (wrong) key pair', () => {
    const wrongKeySigner = new Ed25519TokenSigner(hexToBytes('77'.repeat(32), 32, 'other key'));
    const verifier = new Ed25519TokenVerifier(); // uses the real issuer public key
    const signature = wrongKeySigner.sign(FIELDS);
    expect(verifier.verify(FIELDS, signature)).toBe(false);
  });

  it('rejects a missing/empty signature', () => {
    const verifier = new Ed25519TokenVerifier();
    expect(verifier.verify(FIELDS, '')).toBe(false);
  });
});

/**
 * Mirrors firebase_admin_init.test.ts's pattern for testing fail-fast
 * credential resolution: reset the module registry and restore `process.env`
 * around every test, since `issuer_keys.ts` caches its resolved key at module
 * scope and must not leak state between production/dev-fallback scenarios.
 */
describe('platform/issuer_keys: production fail-fast', () => {
  const ORIGINAL_ENV = { ...process.env };

  beforeEach(() => {
    jest.resetModules();
    process.env = { ...ORIGINAL_ENV };
    delete process.env.ISSUER_PRIVATE_KEY_HEX;
  });

  afterAll(() => {
    process.env = ORIGINAL_ENV;
  });

  it('throws in production when ISSUER_PRIVATE_KEY_HEX is not set', () => {
    process.env.NODE_ENV = 'production';
    const { getIssuerPrivateKey } = require('../src/platform/issuer_keys');
    expect(() => getIssuerPrivateKey()).toThrow(/ISSUER_PRIVATE_KEY_HEX/);
  });

  it('uses ISSUER_PRIVATE_KEY_HEX when set, even in production', () => {
    process.env.NODE_ENV = 'production';
    process.env.ISSUER_PRIVATE_KEY_HEX = '88'.repeat(32);
    const { getIssuerPrivateKey } = require('../src/platform/issuer_keys');
    expect(Buffer.from(getIssuerPrivateKey()).toString('hex')).toBe('88'.repeat(32));
  });

  it('falls back to the fixed development key outside production, with a loud warning', () => {
    process.env.NODE_ENV = 'development';
    const warnSpy = jest.spyOn(console, 'warn').mockImplementation(() => {});
    const { getIssuerPrivateKey } = require('../src/platform/issuer_keys');
    expect(() => getIssuerPrivateKey()).not.toThrow();
    expect(warnSpy).toHaveBeenCalledWith(expect.stringContaining('DEVELOPMENT'));
    warnSpy.mockRestore();
  });
});
