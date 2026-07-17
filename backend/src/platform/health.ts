import { getPool } from './db';
import { getFirebaseAuth, isFirebaseCredentialConfigured } from './firebase';
import { getIssuerPrivateKey } from './issuer_keys';
import { APP_VERSION } from './version';

export type CheckStatus = 'ok' | 'down' | 'dev_mode';

export interface HealthCheck {
  readonly status: CheckStatus;
  readonly error?: string;
}

export interface HealthReport {
  readonly status: 'ok' | 'degraded';
  readonly service: string;
  readonly version: string;
  readonly uptimeSeconds: number;
  readonly checks: {
    readonly database: HealthCheck;
    readonly firebase: HealthCheck;
    readonly issuerKey: HealthCheck;
  };
}

async function checkDatabase(): Promise<HealthCheck> {
  try {
    await getPool().query('SELECT 1');
    return { status: 'ok' };
  } catch (error) {
    return { status: 'down', error: (error as Error).message };
  }
}

/** Initializes (if needed) and reports whether a real service account is configured. */
function checkFirebase(): HealthCheck {
  try {
    getFirebaseAuth();
    return { status: isFirebaseCredentialConfigured() ? 'ok' : 'dev_mode' };
  } catch (error) {
    return { status: 'down', error: (error as Error).message };
  }
}

function checkIssuerKey(): HealthCheck {
  try {
    getIssuerPrivateKey();
    return { status: 'ok' };
  } catch (error) {
    return { status: 'down', error: (error as Error).message };
  }
}

/**
 * GET /health backing logic (production hardening §6). Database and issuer-key
 * availability are hard requirements — either failing marks the service
 * `degraded`. Firebase `dev_mode` (no service account, non-production only)
 * does not degrade the report; a real `down` (including the production
 * fail-fast case) does.
 */
export async function getHealthReport(): Promise<HealthReport> {
  const [database, issuerKey] = await Promise.all([checkDatabase(), Promise.resolve(checkIssuerKey())]);
  const firebase = checkFirebase();

  const healthy = database.status === 'ok' && issuerKey.status === 'ok' && firebase.status !== 'down';

  return {
    status: healthy ? 'ok' : 'degraded',
    service: 'offline-wallet-backend',
    version: APP_VERSION,
    uptimeSeconds: process.uptime(),
    checks: { database, firebase, issuerKey },
  };
}
