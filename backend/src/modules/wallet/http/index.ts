import { Router, Request, Response } from 'express';

/**
 * Wallet (server shadow) context (ARCHITECTURE.md §4.1, §8).
 * Owns: last-synced state, op-counter, offline allowance.
 * Rollback tripwire (FR-SYNC-05); allowance reset (FR-RSK-03).
 * Endpoint (§5.6): POST /v1/wallet/sync.
 * Implemented in a later sync task (outside the demo vertical slice).
 */
export function registerWalletRoutes(router: Router): void {
  router.post('/wallet/sync', (_req: Request, res: Response) =>
    res.status(501).json({ error: 'NOT_IMPLEMENTED', context: 'wallet' }),
  );
}
