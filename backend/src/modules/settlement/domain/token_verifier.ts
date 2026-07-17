import { TokenSigningFields } from '../../../shared/crypto/token_canonical_payload';

/**
 * TokenVerifier — port for issuer signature verification (ARCHITECTURE.md
 * §5.1 "Hexagonal: ports-and-adapters"; "Settlement owns verification"). The
 * domain/application layer depends on this interface only; the Ed25519
 * implementation lives in infra (ed25519_token_verifier.ts).
 */
export interface TokenVerifier {
  /**
   * Verify a hex-encoded signature against the canonical token payload.
   * Never throws — a malformed or forged signature is a `false`, not an
   * exception (settlement must treat attacker-supplied garbage uniformly).
   */
  verify(fields: TokenSigningFields, signatureHex: string): boolean;
}
