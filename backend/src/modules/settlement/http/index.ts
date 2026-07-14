import { Router, Request, Response } from 'express';

/**
 * Settlement (Redemption) context (ARCHITECTURE.md §4.1, §9).
 * Owns: exactly-once redemption, double-spend detection, merchant credit.
 * Unique coin_id index (FR-SET-03); first-valid-wins (FR-SET-05).
 * Endpoint (§5.6): POST /v1/settlement/redeem.
 * Implemented in the Settlement task.
 */
export function registerSettlementRoutes(router: Router): void {
  router.post('/settlement/redeem', (_req: Request, res: Response) =>
    res.status(501).json({ error: 'NOT_IMPLEMENTED', context: 'settlement' }),
  );
}
