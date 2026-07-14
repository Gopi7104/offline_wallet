import { Router, Request, Response } from 'express';

/**
 * Ledger context (ARCHITECTURE.md §4.1, §5.4).
 * Owns: immutable, hash-chained double-entry event log; money-supply
 * invariant (FR-LED-01/02/03). Never mutated; source of truth for value.
 * Endpoints (§5.6): GET /v1/history, internal /ops/reconciliation.
 * Implemented in the Basic ledger task.
 */
export function registerLedgerRoutes(router: Router): void {
  router.get('/history', (_req: Request, res: Response) =>
    res.status(501).json({ error: 'NOT_IMPLEMENTED', context: 'ledger' }),
  );
}
