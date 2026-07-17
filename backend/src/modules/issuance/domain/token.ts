import { Money } from '../../../shared/money';
import { DomainError } from '../../../shared/errors';
import { randomUUID } from 'crypto';
import { toEpochSeconds } from '../../../shared/crypto/token_canonical_payload';

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

  /** Expiry date for a token minted at `issuedAt` with a given validity window. */
  static computeExpiry(issuedAt: Date, expiryDays: number = 30): Date {
    const expiry = new Date(issuedAt);
    expiry.setDate(expiry.getDate() + expiryDays);
    return expiry;
  }

  /**
   * Create a new token. Denomination must be a valid fine denomination
   * (ARCHITECTURE.md D2: {1, 2, 5, 10, 20, 50, 100, 200, 500} INR).
   *
   * `overrides` lets the real minting path (IssuanceService) supply a
   * pre-generated `tokenId` and a real Ed25519 `signature` — the signature
   * must be computed over this exact tokenId/expiry, which the caller needs
   * to know *before* the Token exists, so it can't be computed in here.
   * Callers that don't care about the signature (most domain/unit tests)
   * get a placeholder, matching prior behavior.
   */
  static create(
    denomination: Money,
    ownerId: string,
    issuedAt: Date,
    expiryDays: number = 30,
    overrides: { tokenId?: string; signature?: string } = {},
  ): Token {
    const tokenId = overrides.tokenId ?? randomUUID();
    const expiry = Token.computeExpiry(issuedAt, expiryDays);
    const signature = overrides.signature ?? 'placeholder-issuer-sig';
    return new Token(tokenId, denomination, ownerId, issuedAt, expiry, 'minted', signature);
  }

  isExpired(now: Date): boolean {
    return now > this.expiry;
  }

  /**
   * Wire representation for a client (Task 10 — connects the real
   * backend-issued token to the mobile wallet). Same shape the mobile app's
   * `Token.toJson()`/`fromJson()` and settlement's `SubmittedToken.fromWire()`
   * already speak — `{id, denom, owner, iat, exp, status, sig}` — so this
   * reuses the one wire convention already established for a Token,
   * rather than inventing a second one.
   */
  toWireJson(): Record<string, unknown> {
    return {
      id: this.tokenId,
      denom: this.denomination.paise,
      owner: this.ownerId,
      iat: toEpochSeconds(this.issuedAt),
      exp: toEpochSeconds(this.expiry),
      status: this.status,
      sig: this.bankSignature,
    };
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
