import 'dotenv/config';

/**
 * Environment configuration (ARCHITECTURE.md §11 "Configuration", §12).
 * Infra config, risk limits, rate limits, and logging level are all centralized
 * here — the single source of truth every module reads from, rather than
 * modules reaching into `process.env` directly (Firebase and issuer-key
 * credentials are the one deliberate exception: platform/firebase.ts and
 * platform/issuer_keys.ts already own their own fail-fast credential
 * resolution, which this does not duplicate).
 */
export interface RiskLimitsConfig {
  /** FR-RSK: max value a wallet may hold offline (₹50,000 default). */
  readonly maxOfflineWalletBalancePaise: number;
  /** FR-RSK-01: max value of a single offline payment (₹5,000 default). */
  readonly maxSingleOfflinePaymentPaise: number;
  /** FR-RSK-02: max cumulative value a payer may settle within the rolling window below. */
  readonly maxCumulativeOfflinePaise: number;
  readonly cumulativeWindowHours: number;
  /** Daily transaction count safety net (FR-RSK-02's "5 offline payments/24h" default). */
  readonly maxDailyTransactionCount: number;
  readonly dailyWindowHours: number;
  /** Velocity: a shorter burst window, distinct from the daily count above. */
  readonly velocityMaxCount: number;
  readonly velocityWindowMinutes: number;
}

export interface RateLimitConfig {
  readonly authWindowMs: number;
  readonly authMax: number;
  readonly generalWindowMs: number;
  readonly generalMax: number;
}

export interface AppConfig {
  readonly env: string;
  readonly port: number;
  readonly databaseUrl: string;
  /** Whether the PostgreSQL pool must negotiate TLS (Render requires it; local dev does not). */
  readonly databaseSsl: boolean;
  readonly logLevel: string;
  readonly risk: RiskLimitsConfig;
  readonly rateLimit: RateLimitConfig;
}

/**
 * Default DATABASE_URL matches `.env.example` (local dev Postgres, ARCHITECTURE.md
 * §12). `NODE_ENV=test` gets its own database so the Jest suite never touches
 * dev data. Production must always set DATABASE_URL explicitly — see the
 * fail-fast check in loadConfig() below.
 */
function defaultDatabaseUrl(nodeEnv: string): string {
  const db = nodeEnv === 'test' ? 'offline_wallet_test' : 'offline_wallet';
  return `postgres://wallet:wallet@localhost:5432/${db}`;
}

/**
 * Render (and most managed Postgres providers) require TLS and reject plain
 * connections ("SSL/TLS required"); local/dev Postgres has no TLS listener
 * at all. Detect from the connection target's host rather than NODE_ENV, so
 * a production DATABASE_URL that happens to point at localhost (e.g. an SSH
 * tunnel) still works — `DATABASE_SSL` remains as an explicit escape hatch.
 */
function shouldUseSsl(databaseUrl: string, env: NodeJS.ProcessEnv): boolean {
  if (env.DATABASE_SSL !== undefined) {
    return env.DATABASE_SSL === 'true';
  }
  try {
    const host = new URL(databaseUrl).hostname;
    return host !== 'localhost' && host !== '127.0.0.1';
  } catch {
    return false;
  }
}

function int(env: NodeJS.ProcessEnv, key: string, fallback: number): number {
  const raw = env[key];
  if (raw === undefined || raw.trim() === '') return fallback;
  const parsed = Number(raw);
  if (!Number.isFinite(parsed) || !Number.isInteger(parsed)) {
    throw new Error(`Invalid configuration: ${key} must be an integer, got '${raw}'`);
  }
  return parsed;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const nodeEnv = env.NODE_ENV ?? 'development';
  const isProduction = nodeEnv === 'production';

  // Fail fast: a production backend must never silently fall back to the
  // local-dev connection string (ARCHITECTURE.md §12; "Fail fast for missing
  // production configuration").
  if (isProduction && !env.DATABASE_URL) {
    throw new Error(
      'Configuration error: DATABASE_URL must be set explicitly in production (no local-dev fallback).',
    );
  }

  // NODE_ENV=test always uses the test database, even if a developer's
  // .env sets DATABASE_URL for local dev use — otherwise `npm test`
  // silently truncates dev data (tests/setup/db_setup.ts's beforeAll)
  // whenever DATABASE_URL happens to be set, defeating the whole point
  // of a separate test database.
  const databaseUrl =
    nodeEnv === 'test' ? defaultDatabaseUrl('test') : (env.DATABASE_URL ?? defaultDatabaseUrl(nodeEnv));

  return {
    env: nodeEnv,
    port: int(env, 'PORT', 3000),
    databaseUrl,
    databaseSsl: shouldUseSsl(databaseUrl, env),
    logLevel: env.LOG_LEVEL ?? (isProduction ? 'info' : 'debug'),
    risk: {
      maxOfflineWalletBalancePaise: int(env, 'RISK_MAX_OFFLINE_WALLET_BALANCE_PAISE', 50_000 * 100),
      maxSingleOfflinePaymentPaise: int(env, 'RISK_MAX_SINGLE_PAYMENT_PAISE', 5_000 * 100),
      maxCumulativeOfflinePaise: int(env, 'RISK_MAX_CUMULATIVE_OFFLINE_PAISE', 50_000 * 100),
      cumulativeWindowHours: int(env, 'RISK_CUMULATIVE_WINDOW_HOURS', 24),
      maxDailyTransactionCount: int(env, 'RISK_MAX_DAILY_TX_COUNT', 5),
      dailyWindowHours: int(env, 'RISK_DAILY_WINDOW_HOURS', 24),
      velocityMaxCount: int(env, 'RISK_VELOCITY_MAX_COUNT', 3),
      velocityWindowMinutes: int(env, 'RISK_VELOCITY_WINDOW_MINUTES', 10),
    },
    rateLimit: {
      authWindowMs: int(env, 'RATE_LIMIT_AUTH_WINDOW_MS', 60_000),
      authMax: int(env, 'RATE_LIMIT_AUTH_MAX', 10),
      generalWindowMs: int(env, 'RATE_LIMIT_GENERAL_WINDOW_MS', 60_000),
      generalMax: int(env, 'RATE_LIMIT_GENERAL_MAX', 30),
    },
  };
}
