import 'dotenv/config';

/**
 * Environment configuration (ARCHITECTURE.md §11 "Configuration", §12).
 * Infra config comes from the environment; server-driven business limits
 * are fetched via GET /v1/config in a later task, not hard-coded here.
 */
export interface AppConfig {
  readonly env: string;
  readonly port: number;
  readonly databaseUrl: string;
}

/**
 * Default DATABASE_URL matches `.env.example` (local dev Postgres, ARCHITECTURE.md
 * §12). `NODE_ENV=test` gets its own database so the Jest suite never touches
 * dev data. Production must always set DATABASE_URL explicitly.
 */
function defaultDatabaseUrl(nodeEnv: string): string {
  const db = nodeEnv === 'test' ? 'offline_wallet_test' : 'offline_wallet';
  return `postgres://wallet:wallet@localhost:5432/${db}`;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const nodeEnv = env.NODE_ENV ?? 'development';
  return {
    env: nodeEnv,
    port: Number(env.PORT ?? 3000),
    databaseUrl: env.DATABASE_URL ?? defaultDatabaseUrl(nodeEnv),
  };
}
