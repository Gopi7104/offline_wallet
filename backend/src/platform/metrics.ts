import { getPool } from './db';

/**
 * Basic operational metrics (production hardening §7). Plain JSON, computed
 * on demand from existing tables — no new counters/state to keep in sync,
 * just read what's already there. Same no-auth convention as GET /health
 * (an ops/infra concern, not a business API).
 */
export interface MetricsReport {
  readonly totalWallets: number;
  readonly activeMerchants: number;
  readonly settlementsTotal: number;
  readonly settlementsSucceeded: number;
  readonly settlementsPartial: number;
  readonly settlementsFailed: number;
  readonly riskRejections: number;
}

export async function getMetrics(): Promise<MetricsReport> {
  const pool = getPool();
  const [wallets, merchants, settlementsByStatus, riskFlags] = await Promise.all([
    pool.query<{ count: string }>('SELECT COUNT(*) AS count FROM wallets'),
    pool.query<{ count: string }>('SELECT COUNT(*) AS count FROM merchant_profiles'),
    pool.query<{ status: string; count: string }>(
      'SELECT status, COUNT(*) AS count FROM settlement_records GROUP BY status',
    ),
    pool.query<{ count: string }>('SELECT COUNT(*) AS count FROM risk_flags'),
  ]);

  const byStatus: Record<string, number> = {};
  for (const row of settlementsByStatus.rows) {
    byStatus[row.status] = Number(row.count);
  }
  const settlementsSucceeded = byStatus['SUCCESS'] ?? 0;
  const settlementsPartial = byStatus['PARTIAL'] ?? 0;
  const settlementsFailed = byStatus['REJECTED'] ?? 0;

  return {
    totalWallets: Number(wallets.rows[0]?.count ?? 0),
    activeMerchants: Number(merchants.rows[0]?.count ?? 0),
    settlementsTotal: settlementsSucceeded + settlementsPartial + settlementsFailed,
    settlementsSucceeded,
    settlementsPartial,
    settlementsFailed,
    riskRejections: Number(riskFlags.rows[0]?.count ?? 0),
  };
}
