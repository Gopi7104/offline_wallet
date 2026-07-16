import { readdirSync, readFileSync } from 'fs';
import path from 'path';
import { Pool } from 'pg';

const MIGRATIONS_DIR = path.join(__dirname, '..', '..', 'migrations');

/**
 * Forward-only SQL migration runner (ARCHITECTURE.md §12 "Database migrations:
 * versioned, forward-only migrations checked into the repo"). Applied
 * migrations are tracked in `schema_migrations` so re-running is a no-op;
 * each unapplied file runs inside its own transaction (whole file rolls back
 * together on error, never leaves the schema half-migrated).
 */
export async function runMigrations(pool: Pool): Promise<void> {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      id TEXT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);

  const files = readdirSync(MIGRATIONS_DIR)
    .filter((f) => f.endsWith('.sql'))
    .sort();

  for (const file of files) {
    const { rowCount } = await pool.query('SELECT 1 FROM schema_migrations WHERE id = $1', [file]);
    if (rowCount) continue;

    const sql = readFileSync(path.join(MIGRATIONS_DIR, file), 'utf8');
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(sql);
      await client.query('INSERT INTO schema_migrations (id) VALUES ($1)', [file]);
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }
}
