import { createServer } from './platform/httpServer';
import { loadConfig } from './platform/config';
import { getFirebaseAuth } from './platform/firebase';
import { getPool } from './platform/db';
import { runMigrations } from './platform/migrate';

const config = loadConfig();

async function main(): Promise<void> {
  // Fail fast: a misconfigured Firebase Admin credential (required in
  // production, FR-ID-01) must stop the process before it accepts traffic,
  // not surface as a 500 on the first authenticated request.
  getFirebaseAuth();

  // Fail fast: apply any unapplied PostgreSQL migrations before serving
  // traffic (ARCHITECTURE.md §12 "Database migrations") — never require a
  // manual `psql` step after a deploy.
  await runMigrations(getPool());

  const app = createServer();

  app.listen(config.port, () => {
    // Structured, secret-free logging (ARCHITECTURE.md §11, NFR-SEC-08).
    console.log(
      JSON.stringify({
        msg: 'backend.started',
        env: config.env,
        port: config.port,
        version: '1.1.0',
      }),
    );
  });
}

main().catch((error) => {
  console.error('Fatal startup error:', error);
  process.exit(1);
});
