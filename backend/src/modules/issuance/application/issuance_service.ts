import { randomUUID } from 'crypto';
import { Money } from '../../../shared/money';
import { unwrap } from '../../../shared/result';
import { Token } from '../domain/token';
import { TokenRepository } from '../domain/token_repository';
import { TokenSigner } from '../domain/token_signer';
import { Ed25519TokenSigner } from '../infra/ed25519_token_signer';
import { toEpochSeconds } from '../../../shared/crypto/token_canonical_payload';

/**
 * IssuanceService — use case for token minting (ARCHITECTURE.md §4.1, FR-ISS-02).
 * Creates fine-denomination tokens from a requested amount, each signed by
 * the issuer (Ed25519) before it is persisted — "Issuance owns signing".
 */
export class IssuanceService {
  // Fine denominations (ARCHITECTURE.md D2).
  private static readonly DENOMINATIONS = [500, 200, 100, 50, 20, 10, 5, 2, 1];

  constructor(
    private readonly tokenRepository: TokenRepository,
    private readonly signer: TokenSigner = new Ed25519TokenSigner(),
    private readonly clock: () => Date = () => new Date(),
  ) {}

  /**
   * Mint tokens for a load request. Denomination strategy:
   * - Greedy: use largest denominations first.
   * - Fine denominations: {1, 2, 5, 10, 20, 50, 100, 200, 500} INR (D2).
   */
  async issueTokens(ownerId: string, totalAmount: Money): Promise<Token[]> {
    const denominations = IssuanceService.DENOMINATIONS.map(r => unwrap(Money.fromRupees(r)));

    const tokens: Token[] = [];
    let remaining = totalAmount.paise;
    const now = this.clock();

    for (const denom of denominations) {
      while (remaining >= denom.paise) {
        const tokenId = randomUUID();
        const expiry = Token.computeExpiry(now);
        const signature = this.signer.sign({
          tokenId,
          denominationPaise: denom.paise,
          ownerId,
          issuedAtEpochSeconds: toEpochSeconds(now),
          expiryEpochSeconds: toEpochSeconds(expiry),
        });
        const token = Token.create(denom, ownerId, now, 30, { tokenId, signature });
        tokens.push(token);
        remaining -= denom.paise;
      }
    }

    // Persist tokens.
    await this.tokenRepository.saveMany(tokens);
    return tokens;
  }
}
