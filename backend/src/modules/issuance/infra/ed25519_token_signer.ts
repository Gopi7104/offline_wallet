import { TokenSigner } from '../domain/token_signer';
import { TokenSigningFields, canonicalTokenPayload } from '../../../shared/crypto/token_canonical_payload';
import { signEd25519, bytesToHex } from '../../../shared/crypto/ed25519';
import { getIssuerPrivateKey } from '../../../platform/issuer_keys';

/**
 * Ed25519TokenSigner — production adapter for TokenSigner (ARCHITECTURE.md
 * "Bank Issuer Key ... Signs every coin"). Signs the canonical token payload
 * with the issuer's private key; the key never leaves this adapter.
 */
export class Ed25519TokenSigner implements TokenSigner {
  constructor(private readonly privateKey: Uint8Array = getIssuerPrivateKey()) {}

  sign(fields: TokenSigningFields): string {
    const payload = canonicalTokenPayload(fields);
    const signature = signEd25519(this.privateKey, payload);
    return bytesToHex(signature);
  }
}
