import { Money } from '../../../shared/money';

/**
 * Overall outcome of a settlement (ARCHITECTURE.md §4.1 Settlement, §5.6).
 *  - SUCCESS  : every token was accepted and credited.
 *  - PARTIAL  : some tokens credited, some rejected/duplicated.
 *  - REJECTED : nothing credited (e.g. a repeat settlement of already-spent
 *               tokens — the double-spend path).
 */
export type SettlementStatus = 'SUCCESS' | 'PARTIAL' | 'REJECTED';

/**
 * SettlementResult — immutable summary returned to the merchant and mirrored
 * into the ledger entry. Counts are cardinalities; `creditedAmount` is the sum
 * of accepted token denominations (integer paise). Immutable.
 */
export class SettlementResult {
  constructor(
    readonly settlementId: string,
    readonly merchantId: string,
    readonly acceptedTokenIds: ReadonlyArray<string>,
    readonly rejectedTokenIds: ReadonlyArray<string>,
    readonly duplicateTokenIds: ReadonlyArray<string>,
    readonly creditedAmount: Money,
    readonly ledgerId: string,
    readonly status: SettlementStatus,
    readonly settledAt: Date,
  ) {
    Object.freeze(this.acceptedTokenIds);
    Object.freeze(this.rejectedTokenIds);
    Object.freeze(this.duplicateTokenIds);
    Object.freeze(this);
  }

  get acceptedCount(): number {
    return this.acceptedTokenIds.length;
  }
  get rejectedCount(): number {
    return this.rejectedTokenIds.length;
  }
  get duplicateCount(): number {
    return this.duplicateTokenIds.length;
  }

  /**
   * Derive the status from the token outcomes. `hadInput` guards the empty
   * case (an empty settlement is rejected upstream before a result is built).
   */
  static deriveStatus(
    acceptedCount: number,
    rejectedCount: number,
    duplicateCount: number,
  ): SettlementStatus {
    if (acceptedCount === 0) return 'REJECTED';
    if (rejectedCount > 0 || duplicateCount > 0) return 'PARTIAL';
    return 'SUCCESS';
  }
}
