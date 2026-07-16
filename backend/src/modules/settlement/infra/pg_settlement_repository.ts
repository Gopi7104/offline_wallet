import { Pool } from 'pg';
import { unwrap } from '../../../shared/result';
import { Money } from '../../../shared/money';
import { SettlementResult, SettlementStatus } from '../domain/settlement_result';
import { SettlementRepository } from '../domain/settlement_repository';

interface SettlementRecordRow {
  settlement_id: string;
  merchant_id: string;
  accepted_token_ids: string[];
  rejected_token_ids: string[];
  duplicate_token_ids: string[];
  credited_amount_paise: string;
  ledger_id: string;
  status: SettlementStatus;
  settled_at: Date;
}

function toDomain(row: SettlementRecordRow): SettlementResult {
  return new SettlementResult(
    row.settlement_id,
    row.merchant_id,
    row.accepted_token_ids,
    row.rejected_token_ids,
    row.duplicate_token_ids,
    unwrap(Money.fromPaise(Number(row.credited_amount_paise))),
    row.ledger_id,
    row.status,
    row.settled_at,
  );
}

/**
 * PgSettlementRepository — PostgreSQL adapter for the Settlement (Redemption)
 * context (ARCHITECTURE.md §5.2, migration 004). Owns the merchant settled
 * balance (`merchant_settlement_balances`) and the append-only settlement
 * history (`settlement_records`); replaces InMemorySettlementRepository.
 */
export class PgSettlementRepository implements SettlementRepository {
  constructor(private readonly pool: Pool) {}

  async record(result: SettlementResult): Promise<void> {
    await this.pool.query(
      `INSERT INTO settlement_records
         (settlement_id, merchant_id, accepted_token_ids, rejected_token_ids,
          duplicate_token_ids, credited_amount_paise, ledger_id, status, settled_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
      [
        result.settlementId,
        result.merchantId,
        JSON.stringify(result.acceptedTokenIds),
        JSON.stringify(result.rejectedTokenIds),
        JSON.stringify(result.duplicateTokenIds),
        result.creditedAmount.paise,
        result.ledgerId,
        result.status,
        result.settledAt,
      ],
    );
  }

  /**
   * Additive credit as a single UPSERT statement — atomic and safe under
   * concurrent settlements crediting the same merchant (no read-modify-write
   * race). No-op for a zero amount, matching InMemorySettlementRepository.
   */
  async creditMerchant(merchantId: string, amount: Money): Promise<void> {
    if (amount.isZero()) return;
    await this.pool.query(
      `INSERT INTO merchant_settlement_balances (merchant_id, settled_paise)
       VALUES ($1, $2)
       ON CONFLICT (merchant_id) DO UPDATE SET
         settled_paise = merchant_settlement_balances.settled_paise + EXCLUDED.settled_paise`,
      [merchantId, amount.paise],
    );
  }

  async settledBalance(merchantId: string): Promise<Money> {
    const { rows } = await this.pool.query<{ settled_paise: string }>(
      'SELECT settled_paise FROM merchant_settlement_balances WHERE merchant_id = $1',
      [merchantId],
    );
    return rows[0] ? unwrap(Money.fromPaise(Number(rows[0].settled_paise))) : Money.zero();
  }

  async historyFor(merchantId: string): Promise<SettlementResult[]> {
    const { rows } = await this.pool.query<SettlementRecordRow>(
      'SELECT * FROM settlement_records WHERE merchant_id = $1 ORDER BY seq ASC',
      [merchantId],
    );
    return rows.map(toDomain);
  }
}
