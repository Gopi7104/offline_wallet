import { Money } from '../../../shared/money';
import { Token } from '../../issuance/domain/token';
import { DomainError } from '../../../shared/errors';

/** Raised by Wallet.markTokensAsTransferred() when a token ID isn't in this wallet. */
export class TokenNotFoundError extends DomainError {
  readonly code = 'TOKEN_NOT_FOUND';
  constructor(tokenId: string) {
    super(`Token ${tokenId} not found in wallet`);
  }
}

/**
 * Wallet — aggregate root (ARCHITECTURE.md §4.1, §6.2).
 * Task 3: stores digital cash tokens (not a numeric balance).
 * Balance is computed from the sum of token denominations.
 * Immutable: new Wallet returned on each state change.
 */
export class Wallet {
  constructor(
    readonly accountId: string,
    readonly tokens: ReadonlyArray<Token>,
  ) {}

  /**
   * Compute the total balance from token denominations.
   * This is the "in_wallet" bucket from the money-supply invariant (FR-LED-03).
   */
  get balance(): Money {
    return this.tokens.reduce((sum, token) => sum.add(token.denomination), Money.zero());
  }

  /**
   * Add tokens to the wallet (load from bank). Immutable.
   * Transitions each incoming token minted -> in_wallet (ARCHITECTURE.md §4.3);
   * throws IllegalTokenTransition if a token isn't currently 'minted'.
   */
  addTokens(newTokens: Token[]): Wallet {
    const received = newTokens.map(t => t.withStatus('in_wallet'));
    return new Wallet(this.accountId, [...this.tokens, ...received]);
  }

  /**
   * Mark tokens as transferred (in_wallet -> in_transit). Immutable.
   * Throws TokenNotFoundError if a tokenId isn't in this wallet, or
   * IllegalTokenTransition (via Token.withStatus) if a matched token
   * isn't currently 'in_wallet'.
   */
  markTokensAsTransferred(tokenIds: string[]): Wallet {
    const idsSet = new Set(tokenIds);
    const byId = new Map(this.tokens.map(t => [t.tokenId, t]));
    for (const id of idsSet) {
      if (!byId.has(id)) {
        throw new TokenNotFoundError(id);
      }
    }
    const updated = this.tokens.map(t => (idsSet.has(t.tokenId) ? t.withStatus('in_transit') : t));
    return new Wallet(this.accountId, updated);
  }

  static empty(accountId: string): Wallet {
    return new Wallet(accountId, []);
  }
}
