import { createServer } from './platform/httpServer';
import { loadConfig } from './platform/config';
import { getFirebaseAuth } from './platform/firebase';
import { getIssuerPrivateKey } from './platform/issuer_keys';
import { getPool } from './platform/db';
import { runMigrations } from './platform/migrate';
import { logger } from './platform/logger';
import { APP_VERSION } from './platform/version';

const config = loadConfig();

async function main(): Promise<void> {
  // Fail fast: a misconfigured Firebase Admin credential (required in
  // production, FR-ID-01) must stop the process before it accepts traffic,
  // not surface as a 500 on the first authenticated request.
  getFirebaseAuth();

  // Fail fast: a missing issuer signing key in production must stop the
  // process before it accepts traffic — a backend that cannot sign coins
  // authentically must not serve traffic (Ed25519 integration).
  getIssuerPrivateKey();

  // Fail fast: apply any unapplied PostgreSQL migrations before serving
  // traffic (ARCHITECTURE.md §12 "Database migrations") — never require a
  // manual `psql` step after a deploy.
  await runMigrations(getPool());

  const app = createServer();

  app.listen(config.port, () => {
    logger.info('backend.started', { env: config.env, port: config.port, version: APP_VERSION });
  });
}

main().catch((error) => {
  logger.error('backend.fatal_startup_error', { message: (error as Error).message });
  process.exit(1);
});
