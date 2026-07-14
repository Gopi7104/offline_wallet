import { Money } from '../../../shared/money';
import { DomainError } from '../../../shared/errors';
import { randomUUID } from 'crypto';

/**
 * Token — digital cash (ARCHITECTURE.md §4.2, §4.3).
 * Immutable value object representing a signed, fine-denomination coin.
 * Fields: tokenId, denomination, ownerId, issuedAt, expiry, status, signature.
 * Status lifecycle: minted → in_wallet → in_transit → redeemed (or expired/voided).
 */
export type TokenStatus = 'minted' | 'in_wallet' | 'in_transit' | 'redeemed' | 'expired' | 'voided';

/** Raised by Token.withStatus() when a status change violates the lifecycle. */
export class IllegalTokenTransition extends DomainError {
  readonly code = 'ILLEGAL_TOKEN_TRANSITION';
  constructor(tokenId: string, from: TokenStatus, to: TokenStatus) {
    super(`Token ${tokenId} cannot transition from '${from}' to '${to}'`);
  }
}

/** Legal forward transitions in the token lifecycle (ARCHITECTURE.md §4.3). */
const ALLOWED_TRANSITIONS: Record<TokenStatus, ReadonlyArray<TokenStatus>> = {
  minted: ['in_wallet'],
  in_wallet: ['in_transit'],
  in_transit: ['redeemed'],
  redeemed: [],
  expired: [],
  voided: [],
};

export class Token {
  constructor(
    readonly tokenId: string,
    readonly denomination: Money,
    readonly ownerId: string,
    readonly issuedAt: Date,
    readonly expiry: Date,
    readonly status: TokenStatus,
    readonly bankSignature: string, // Placeholder; Ed25519 in a later task.
  ) {}

  /**
   * Create a new token. Denomination must be a valid fine denomination
   * (ARCHITECTURE.md D2: {1, 2, 5, 10, 20, 50, 100, 200, 500} INR).
   */
  static create(
    denomination: Money,
    ownerId: string,
    issuedAt: Date,
    expiryDays: number = 30,
  ): Token {
    const expiry = new Date(issuedAt);
    expiry.setDate(expiry.getDate() + expiryDays);
    return new Token(
      randomUUID(),
      denomination,
      ownerId,
      issuedAt,
      expiry,
      'minted',
      'placeholder-issuer-sig', // Task 5: replace with Ed25519 issuer signature.
    );
  }

  isExpired(now: Date): boolean {
    return now > this.expiry;
  }

  /**
   * Advance status through the lifecycle (ARCHITECTURE.md §4.3).
   * Immutable: returns a new Token. Throws IllegalTokenTransition if
   * `newStatus` is not a legal next state from the current status.
   */
  withStatus(newStatus: TokenStatus): Token {
    if (!ALLOWED_TRANSITIONS[this.status].includes(newStatus)) {
      throw new IllegalTokenTransition(this.tokenId, this.status, newStatus);
    }
    return new Token(
      this.tokenId,
      this.denomination,
      this.ownerId,
      this.issuedAt,
      this.expiry,
      newStatus,
      this.bankSignature,
    );
  }
}
