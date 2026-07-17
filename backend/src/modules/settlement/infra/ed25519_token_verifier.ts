import { TokenVerifier } from '../domain/token_verifier';
import { TokenSigningFields, canonicalTokenPayload } from '../../../shared/crypto/token_canonical_payload';
import { verifyEd25519, ED25519_SIGNATURE_BYTES } from '../../../shared/crypto/ed25519';
import { getIssuerPublicKey } from '../../../platform/issuer_keys';

const HEX_SIGNATURE_PATTERN = new RegExp(`^[0-9a-fA-F]{${ED25519_SIGNATURE_BYTES * 2}}$`);

/**
 * Ed25519TokenVerifier — production adapter for TokenVerifier. Verifies the
 * issuer signature with the issuer's PUBLIC key only; never has access to (or
 * needs) the private key. Rejects anything that isn't a well-formed 64-byte
 * hex signature before ever touching the crypto library — a missing,
 * truncated, or non-hex `sig` field is a straightforward `false`, not an
 * exception to catch.
 */
export class Ed25519TokenVerifier implements TokenVerifier {
  constructor(private readonly publicKey: Uint8Array = getIssuerPublicKey()) {}

  verify(fields: TokenSigningFields, signatureHex: string): boolean {
    if (!HEX_SIGNATURE_PATTERN.test(signatureHex)) return false;
    const signature = new Uint8Array(Buffer.from(signatureHex, 'hex'));
    const payload = canonicalTokenPayload(fields);
    return verifyEd25519(this.publicKey, payload, signature);
  }
}
