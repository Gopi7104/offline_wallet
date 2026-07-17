/**
 * PayerActivityRepository — port for the rolling history of a payer's
 * accepted offline payments, backing the cumulative/daily-count/velocity
 * risk rules. Owned by Risk, independent of Settlement's own tables
 * (bounded-context ownership — Risk never reaches into `spent_tokens`).
 */
export interface PayerActivityRepository {
  record(accountId: string, amountPaise: number, occurredAt: Date): Promise<void>;
  /** Sum of amounts recorded for `accountId` at or after `since`. */
  sumSince(accountId: string, since: Date): Promise<number>;
  /** Count of records for `accountId` at or after `since`. */
  countSince(accountId: string, since: Date): Promise<number>;
}
