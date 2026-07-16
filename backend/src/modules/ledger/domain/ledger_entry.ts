import { Money } from '../../../shared/money';
import { randomUUID, createHash } from 'crypto';

/**
 * LedgerEntry — an immutable, append-only event in the value log
 * (ARCHITECTURE.md §4.1 Ledger, §5.4; FR-LED-01/02).
 *
 * Task 9: the Settlement context appends one entry per settlement attempt,
 * recording what was credited and which tokens were accepted / rejected /
 * flagged as double-spends. The entry is hash-chained to the previous entry
 * (`prevHash` → `hash`) so any post-hoc mutation is detectable (tamper
 * evidence, NFR-SEC): the log is never modified in place.
 *
 * The object is frozen at construction; there is no mutator. Immutable.
 */
export type SettlementLedgerStatus = 'SUCCESS' | 'PARTIAL' | 'REJECTED';

export const LEDGER_EVENT_SETTLEMENT = 'SETTLEMENT' as const;

export class LedgerEntry {
  private constructor(
    readonly ledgerId: string,
    readonly eventType: string,
    readonly merchantId: string,
    readonly amount: Money,
    readonly acceptedTokenIds: ReadonlyArray<string>,
    readonly rejectedTokenIds: ReadonlyArray<string>,
    readonly duplicateTokenIds: ReadonlyArray<string>,
    readonly status: SettlementLedgerStatus,
    readonly timestamp: Date,
    /** Hash of the immediately preceding entry, or null for the first entry. */
    readonly prevHash: string | null,
    /** SHA-256 over this entry's canonical content + prevHash. */
    readonly hash: string,
  ) {
    // Defensive immutability: no field or nested array can be reassigned.
    Object.freeze(this.acceptedTokenIds);
    Object.freeze(this.rejectedTokenIds);
    Object.freeze(this.duplicateTokenIds);
    Object.freeze(this);
  }

  /**
   * Build a settlement ledger entry. `prevHash` is the hash of the previous
   * entry in the chain (null for the genesis entry). The id and hash are
   * derived here; callers never supply them.
   */
  static forSettlement(params: {
    merchantId: string;
    amount: Money;
    acceptedTokenIds: string[];
    rejectedTokenIds: string[];
    duplicateTokenIds: string[];
    status: SettlementLedgerStatus;
    timestamp: Date;
    prevHash: string | null;
  }): LedgerEntry {
    const ledgerId = `LED-${randomUUID()}`;
    const hash = LedgerEntry.computeHash({
      ledgerId,
      eventType: LEDGER_EVENT_SETTLEMENT,
      merchantId: params.merchantId,
      amountPaise: params.amount.paise,
      acceptedTokenIds: params.acceptedTokenIds,
      rejectedTokenIds: params.rejectedTokenIds,
      duplicateTokenIds: params.duplicateTokenIds,
      status: params.status,
      timestamp: params.timestamp.toISOString(),
      prevHash: params.prevHash,
    });
    return new LedgerEntry(
      ledgerId,
      LEDGER_EVENT_SETTLEMENT,
      params.merchantId,
      params.amount,
      [...params.acceptedTokenIds],
      [...params.rejectedTokenIds],
      [...params.duplicateTokenIds],
      params.status,
      params.timestamp,
      params.prevHash,
      hash,
    );
  }

  private static computeHash(content: unknown): string {
    return createHash('sha256').update(JSON.stringify(content)).digest('hex');
  }

  /**
   * Reconstruct an entry already persisted by a repository (its id and hash
   * were computed once, at `forSettlement` time, and must not be recomputed
   * here) — a plain row-to-object mapper, not a second way to author ledger
   * entries. Infrastructure-only; application/domain code never calls this.
   */
  static rehydrate(params: {
    ledgerId: string;
    eventType: string;
    merchantId: string;
    amount: Money;
    acceptedTokenIds: string[];
    rejectedTokenIds: string[];
    duplicateTokenIds: string[];
    status: SettlementLedgerStatus;
    timestamp: Date;
    prevHash: string | null;
    hash: string;
  }): LedgerEntry {
    return new LedgerEntry(
      params.ledgerId,
      params.eventType,
      params.merchantId,
      params.amount,
      [...params.acceptedTokenIds],
      [...params.rejectedTokenIds],
      [...params.duplicateTokenIds],
      params.status,
      params.timestamp,
      params.prevHash,
      params.hash,
    );
  }
}
