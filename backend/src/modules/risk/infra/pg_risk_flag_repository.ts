import { Pool } from 'pg';
import { RiskFlag } from '../domain/risk_flag';
import { RiskFlagRepository } from '../domain/risk_flag_repository';

/** PgRiskFlagRepository — PostgreSQL adapter (migration 007 `risk_flags`). */
export class PgRiskFlagRepository implements RiskFlagRepository {
  constructor(private readonly pool: Pool) {}

  async raise(flag: RiskFlag): Promise<void> {
    await this.pool.query(
      `INSERT INTO risk_flags (id, subject_type, subject_id, reason_code, message, severity, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [flag.id, flag.subjectType, flag.subjectId, flag.reasonCode, flag.message, flag.severity, flag.createdAt],
    );
  }

  async countAll(): Promise<number> {
    const { rows } = await this.pool.query<{ count: string }>('SELECT COUNT(*) AS count FROM risk_flags');
    return Number(rows[0]?.count ?? 0);
  }
}
