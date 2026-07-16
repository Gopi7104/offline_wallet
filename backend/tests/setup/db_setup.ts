import { getPool, closePool } from '../../src/platform/db';
import { runMigrations } from '../../src/platform/migrate';

const TABLES = [
  'wallet_tokens',
  'wallets',
  'tokens',
  'merchant_profiles',
  'settlement_records',
  'merchant_settlement_balances',
  'spent_tokens',
  'ledger_entries',
];

/**
 * Runs once per test FILE (Jest gives every file its own module registry, so
 * this `beforeAll`/`afterAll` pair is registered fresh each time): migrate the
 * test database (offline_wallet_test, see config.ts) up to date, then
 * truncate every table so each test file starts from the same clean slate
 * the old in-memory Maps gave for free. Tests within a file still accumulate
 * state across `it` blocks exactly as before (e.g. wallet.test.ts's shared
 * `const app = createServer()`).
 */
beforeAll(async () => {
  const pool = getPool();
  await runMigrations(pool);
  await pool.query(`TRUNCATE TABLE ${TABLES.join(', ')} RESTART IDENTITY CASCADE`);
});

afterAll(async () => {
  await closePool();
});
