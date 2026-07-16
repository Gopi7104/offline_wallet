import { Pool, PoolClient } from 'pg';
import { loadConfig } from './config';

/**
 * PostgreSQL connection pool (ARCHITECTURE.md §5.1 "Infrastructure / Adapters",
 * §12). Repositories are the only callers — domain/application code never
 * imports this module (dependency rule, §5.1). One pool per process, lazily
 * created so tests that never touch the DB don't pay for a connection.
 */
let pool: Pool | undefined;

export function getPool(): Pool {
  if (!pool) {
    const { databaseUrl } = loadConfig();
    pool = new Pool({ connectionString: databaseUrl });
  }
  return pool;
}

/**
 * Run `work` inside a single DB transaction: BEGIN, then COMMIT on success or
 * ROLLBACK on any thrown error (ARCHITECTURE.md §5.3 "atomic value movements").
 * The client is always released back to the pool.
 */
export async function withTransaction<T>(work: (client: PoolClient) => Promise<T>): Promise<T> {
  const client = await getPool().connect();
  try {
    await client.query('BEGIN');
    const result = await work(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

/** Test/shutdown helper: closes the pool so the process can exit cleanly. */
export async function closePool(): Promise<void> {
  if (pool) {
    await pool.end();
    pool = undefined;
  }
}
