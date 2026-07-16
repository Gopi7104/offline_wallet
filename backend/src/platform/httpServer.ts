import express, { Express, Request, Response, NextFunction } from 'express';
import { registerIdentityRoutes } from '../modules/identity/http';
import { resolveAccountId } from '../modules/identity/http/auth_middleware';
import { registerIssuanceRoutes } from '../modules/issuance/http';
import { registerWalletRoutes } from '../modules/wallet/http';
import { registerPaymentRoutes } from '../modules/payment/http';
import { registerSettlementRoutes } from '../modules/settlement/http';
import { registerLedgerRoutes } from '../modules/ledger/http';
import { registerRiskRoutes } from '../modules/risk/http';
import { PgMerchantRepository } from '../modules/identity/infra/pg_merchant_repository';
import { PgLedgerRepository } from '../modules/ledger/infra/pg_ledger_repository';
import { getPool } from './db';

/**
 * Composition root for the modular monolith (ARCHITECTURE.md §5.1).
 * Each bounded context mounts its own router under the /v1 prefix; the
 * server itself owns no business logic. Routes are stubs until their
 * feature task lands.
 */
export function createServer(): Express {
  const app = express();
  app.use(express.json());

  // Liveness/readiness — infra concern, no auth (ARCHITECTURE.md §11).
  app.get('/health', (_req: Request, res: Response) => {
    res.status(200).json({ status: 'ok', service: 'offline-wallet-backend', version: '1.1.0' });
  });

  // PostgreSQL-backed (migrations 001-005); every module below shares one
  // connection pool. Shared merchant store: Merchant Mode (Identity) enables
  // merchants; the Customer Pay endpoint (Payment) validates against the same
  // repository, and Settlement validates settling merchants against it too.
  const pool = getPool();
  const merchantRepository = new PgMerchantRepository(pool);
  // Shared append-only ledger: Settlement appends one entry per settlement;
  // the Ledger context exposes the same log read-only.
  const ledgerRepository = new PgLedgerRepository(pool);

  const v1 = express.Router();
  // Resolves req.accountId from the Firebase ID token (Authorization: Bearer)
  // for every bounded context below — see auth_middleware.ts (FR-ID-01).
  v1.use(resolveAccountId);
  registerIdentityRoutes(v1, { merchantRepository });
  registerIssuanceRoutes(v1);
  registerWalletRoutes(v1);
  registerPaymentRoutes(v1, { merchantRepository });
  registerSettlementRoutes(v1, { merchantRepository, ledgerRepository });
  registerLedgerRoutes(v1, { ledgerRepository });
  registerRiskRoutes(v1);
  app.use('/v1', v1);

  // Global error handler: return a consistent JSON object (never HTML) for
  // malformed request bodies and other unhandled errors. Must be registered
  // last and take 4 args so Express treats it as error-handling middleware.
  app.use((err: unknown, _req: Request, res: Response, next: NextFunction) => {
    if (res.headersSent) return next(err);
    // body-parser marks malformed JSON with type 'entity.parse.failed'.
    if (err && (err as { type?: string }).type === 'entity.parse.failed') {
      res.status(400).json({ error: 'INVALID_JSON', message: 'Request body is not valid JSON' });
      return;
    }
    console.error('Unhandled error:', err);
    res.status(500).json({ error: 'INTERNAL_ERROR', message: 'An error occurred' });
  });

  return app;
}
