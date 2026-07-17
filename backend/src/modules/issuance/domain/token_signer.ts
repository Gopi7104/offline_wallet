import { TokenSigningFields } from '../../../shared/crypto/token_canonical_payload';

/**
 * TokenSigner — port for issuer signing (ARCHITECTURE.md §5.1 "Hexagonal:
 * ports-and-adapters"; "Issuance owns signing"). The domain/application layer
 * depends on this interface only; the Ed25519 implementation lives in infra
 * (ed25519_token_signer.ts), keeping the crypto library out of the domain.
 */
export interface TokenSigner {
  /** Sign the canonical token payload. Returns a hex-encoded signature. */
  sign(fields: TokenSigningFields): string;
}
