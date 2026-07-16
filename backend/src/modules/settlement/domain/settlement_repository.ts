import { Money } from '../../../shared/money';
import { SettlementResult } from './settlement_result';

/**
 * SettlementRepository — port owning the merchant *settlement balance* and the
 * record of every settlement (ARCHITECTURE.md §5.2: `settlement_balance` is
 * owned by the Settlement context, not the Identity merchant projection).
 *
 * `creditMerchant` is additive and only ever called with the accepted amount,
 * so a repeat settlement of already-spent tokens (credited = 0) leaves the
 * balance unchanged — the merchant is credited exactly once.
 */
export interface SettlementRepository {
  /** Persist a completed settlement record (append-only history). */
  record(result: SettlementResult): Promise<void>;
  /** Add `amount` to the merchant's settled balance. */
  creditMerchant(merchantId: string, amount: Money): Promise<void>;
  /** Current settled balance for a merchant (zero if none). */
  settledBalance(merchantId: string): Promise<Money>;
  /** All settlement records for a merchant, in record order. */
  historyFor(merchantId: string): Promise<SettlementResult[]>;
}
