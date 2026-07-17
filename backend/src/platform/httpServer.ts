import express, { Express, Request, Response, NextFunction } from 'express';
import helmet from 'helmet';
import { registerIdentityRoutes } from '../modules/identity/http';
import { resolveAccountId } from '../modules/identity/http/auth_middleware';
import { registerIssuanceRoutes } from '../modules/issuance/http';
import { registerWalletRoutes } from '../modules/wallet/http';
import { registerSettlementRoutes } from '../modules/settlement/http';
import { registerLedgerRoutes } from '../modules/ledger/http';
import { registerRiskRoutes } from '../modules/risk/http';
import { PgMerchantRepository } from '../modules/identity/infra/pg_merchant_repository';
import { PgLedgerRepository } from '../modules/ledger/infra/pg_ledger_repository';
import { PgSettlementRepository } from '../modules/settlement/infra/pg_settlement_repository';
import { getPool } from './db';
import { getHealthReport } from './health';
import { getMetrics } from './metrics';
import { logger } from './logger';
import { sendError, sendInternalError } from '../shared/http_errors';
import { loadConfig } from './config';
import { createAuthRateLimiter, createGeneralRateLimiter } from './rate_limit';

/**
 * Composition root for the modular monolith (ARCHITECTURE.md §5.1).
 * Each bounded context mounts its own router under the /v1 prefix; the
 * server itself owns no business logic. Routes are stubs until their
 * feature task lands.
 */
export function createServer(): Express {
  const app = express();
  // Secure HTTP response headers (production hardening §9 "secure defaults") —
  // HSTS, X-Content-Type-Options, disabled X-Powered-By, etc. No API/behavior
  // change, just headers.
  app.use(helmet());
  app.use(express.json());

  // Liveness/readiness — infra concern, no auth (ARCHITECTURE.md §11).
  // Reports DB/Firebase/issuer-key availability + uptime + version (production
  // hardening §6); 200 when healthy, 503 when any hard-required check fails.
  app.get('/health', async (_req: Request, res: Response) => {
    try {
      const report = await getHealthReport();
      res.status(report.status === 'ok' ? 200 : 503).json(report);
    } catch (error) {
      logger.error('health.check_failed', { error: (error as Error).message });
      sendInternalError(res);
    }
  });

  // Basic operational metrics (production hardening §7) — same no-auth
  // convention as /health; an ops/infra concern, not a business API.
  app.get('/metrics', async (_req: Request, res: Response) => {
    try {
      res.status(200).json(await getMetrics());
    } catch (error) {
      logger.error('metrics.fetch_failed', { error: (error as Error).message });
      sendInternalError(res);
    }
  });

  // PostgreSQL-backed (migrations 001-005); every module below shares one
  // connection pool. Shared merchant store: Merchant Mode (Identity) enables
  // merchants, and Settlement validates settling merchants against the same
  // repository.
  const pool = getPool();
  const merchantRepository = new PgMerchantRepository(pool);
  // Shared append-only ledger: Settlement appends one entry per settlement;
  // the Ledger context exposes the same log read-only.
  const ledgerRepository = new PgLedgerRepository(pool);
  // Shared settlement balance store: Settlement credits it, Identity reads it
  // back for the merchant dashboard's "Settled" total (merchant_service.ts).
  const settlementRepository = new PgSettlementRepository(pool);

  const v1 = express.Router();
  // Resolves req.accountId from the Firebase ID token (Authorization: Bearer)
  // for every bounded context below — see auth_middleware.ts (FR-ID-01).
  v1.use(resolveAccountId);

  // Rate limiting (production hardening §8): sensitive endpoints get a
  // per-account request budget (429 when exceeded). Registered as an extra
  // layer on the exact path+method BEFORE each module's real handler — Express
  // runs same-path layers in registration order, so this always executes
  // first without any module needing to know about rate limiting itself.
  const { rateLimit } = loadConfig();
  const authLimiter = createAuthRateLimiter(rateLimit.authWindowMs, rateLimit.authMax);
  const generalLimiter = createGeneralRateLimiter(rateLimit.generalWindowMs, rateLimit.generalMax);
  v1.post('/auth/session', authLimiter);
  v1.post('/wallet/load', generalLimiter);
  v1.post('/settlement', generalLimiter);
  v1.post('/merchant/enable', generalLimiter);
  v1.post('/devices/register', generalLimiter);
  v1.post('/devices/:deviceId/last-seen', generalLimiter);

  registerIdentityRoutes(v1, { merchantRepository, settlementRepository });
  registerIssuanceRoutes(v1);
  registerWalletRoutes(v1);
  registerSettlementRoutes(v1, { merchantRepository, ledgerRepository, settlementRepository });
  registerLedgerRoutes(v1, { ledgerRepository });
  registerRiskRoutes(v1);
  app.use('/v1', v1);

  // Consistent JSON (never HTML) for any unmatched route — production
  // hardening §5 "standardize API errors".
  app.use((req: Request, res: Response) => {
    sendError(res, 404, 'NOT_FOUND', `No route matches ${req.method} ${req.path}`);
  });

  // Global error handler: return a consistent JSON object (never HTML, never
  // a stack trace) for malformed request bodies and other unhandled errors.
  // Must be registered last and take 4 args so Express treats it as
  // error-handling middleware.
  app.use((err: unknown, _req: Request, res: Response, next: NextFunction) => {
    if (res.headersSent) return next(err);
    // body-parser marks malformed JSON with type 'entity.parse.failed'.
    if (err && (err as { type?: string }).type === 'entity.parse.failed') {
      sendError(res, 400, 'INVALID_JSON', 'Request body is not valid JSON');
      return;
    }
    logger.error('http.unhandled_error', { message: (err as Error)?.message ?? String(err) });
    sendInternalError(res);
  });

  return app;
}
