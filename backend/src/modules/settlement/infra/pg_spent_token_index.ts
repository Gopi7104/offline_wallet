import { Pool } from 'pg';
import { SpentTokenIndex } from '../domain/spent_token_index';

/**
 * PgSpentTokenIndex — the real double-spend enforcer (ARCHITECTURE.md §4.1
 * Settlement, D3, ADR-7; migration 004 `spent_tokens`). The PRIMARY KEY on
 * token_id is what makes first-claim-wins deterministic under concurrency —
 * `tryClaim` is a single `INSERT ... ON CONFLICT DO NOTHING`; Postgres itself
 * resolves the race, not application code. Replaces InMemorySpentTokenIndex.
 */
export class PgSpentTokenIndex implements SpentTokenIndex {
  constructor(private readonly pool: Pool) {}

  async tryClaim(tokenId: string): Promise<boolean> {
    const { rowCount } = await this.pool.query(
      'INSERT INTO spent_tokens (token_id) VALUES ($1) ON CONFLICT (token_id) DO NOTHING',
      [tokenId],
    );
    return rowCount === 1;
  }

  async isSpent(tokenId: string): Promise<boolean> {
    const { rows } = await this.pool.query('SELECT 1 FROM spent_tokens WHERE token_id = $1', [tokenId]);
    return rows.length > 0;
  }
}
