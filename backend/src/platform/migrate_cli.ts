import { getPool, closePool } from './db';
import { runMigrations } from './migrate';

/** `npm run migrate` — apply any unapplied migrations to DATABASE_URL. */
async function main(): Promise<void> {
  await runMigrations(getPool());
  console.log(JSON.stringify({ msg: 'migrations.applied' }));
}

main()
  .catch((error) => {
    console.error('Migration failed:', error);
    process.exitCode = 1;
  })
  .finally(() => {
    void closePool();
  });
