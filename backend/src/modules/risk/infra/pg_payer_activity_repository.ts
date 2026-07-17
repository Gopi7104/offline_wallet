import { Pool } from 'pg';
import { PayerActivityRepository } from '../domain/payer_activity_repository';

/** PgPayerActivityRepository — PostgreSQL adapter (migration 007 `risk_payer_activity`). */
export class PgPayerActivityRepository implements PayerActivityRepository {
  constructor(private readonly pool: Pool) {}

  async record(accountId: string, amountPaise: number, occurredAt: Date): Promise<void> {
    await this.pool.query(
      'INSERT INTO risk_payer_activity (account_id, amount_paise, occurred_at) VALUES ($1, $2, $3)',
      [accountId, amountPaise, occurredAt],
    );
  }

  async sumSince(accountId: string, since: Date): Promise<number> {
    const { rows } = await this.pool.query<{ total: string | null }>(
      'SELECT SUM(amount_paise) AS total FROM risk_payer_activity WHERE account_id = $1 AND occurred_at >= $2',
      [accountId, since],
    );
    return Number(rows[0]?.total ?? 0);
  }

  async countSince(accountId: string, since: Date): Promise<number> {
    const { rows } = await this.pool.query<{ count: string }>(
      'SELECT COUNT(*) AS count FROM risk_payer_activity WHERE account_id = $1 AND occurred_at >= $2',
      [accountId, since],
    );
    return Number(rows[0]?.count ?? 0);
  }
}
