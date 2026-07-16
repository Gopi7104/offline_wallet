/**
 * SpentTokenIndex — the double-spend enforcer (ARCHITECTURE.md §4.1 Settlement,
 * D3; FR-SET-03/05). Models the production UNIQUE index on
 * `spent_coins(coin_id)`: the first settlement to claim a token wins
 * deterministically; every later claim of the same token id is rejected as a
 * double-spend. Exactly-once redemption.
 *
 * Domain defines the port; infrastructure implements it (in-memory for Task 9,
 * a unique DB index in the PostgreSQL adapter). Async because the real
 * enforcement is a DB-level UNIQUE constraint (ADR-7) — every other
 * repository port in this codebase is already Promise-based; this one is
 * brought in line with them rather than left as the one synchronous port a
 * network-backed adapter cannot honestly implement.
 */
export interface SpentTokenIndex {
  /**
   * Atomically claim a token id for redemption. Resolves true if this call was
   * the first to claim it (token becomes spent); false if it was already
   * spent (double-spend / already redeemed). Never throws for a duplicate —
   * "insert-or-conflict" is a normal, expected outcome.
   */
  tryClaim(tokenId: string): Promise<boolean>;

  /** Whether a token id has already been redeemed. */
  isSpent(tokenId: string): Promise<boolean>;
}
