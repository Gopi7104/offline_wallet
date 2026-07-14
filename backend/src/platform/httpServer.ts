import express, { Express, Request, Response } from 'express';
import { registerIdentityRoutes } from '../modules/identity/http';
import { registerIssuanceRoutes } from '../modules/issuance/http';
import { registerWalletRoutes } from '../modules/wallet/http';
import { registerMerchantRoutes } from '../modules/merchant/http';
import { registerPaymentRoutes } from '../modules/payment/http';
import { registerSettlementRoutes } from '../modules/settlement/http';
import { registerLedgerRoutes } from '../modules/ledger/http';
import { registerRiskRoutes } from '../modules/risk/http';

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

  const v1 = express.Router();
  registerIdentityRoutes(v1);
  registerIssuanceRoutes(v1);
  registerWalletRoutes(v1);
  registerMerchantRoutes(v1);
  registerPaymentRoutes(v1);
  registerSettlementRoutes(v1);
  registerLedgerRoutes(v1);
  registerRiskRoutes(v1);
  app.use('/v1', v1);

  return app;
}
