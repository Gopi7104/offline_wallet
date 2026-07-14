import { Router, Request, Response } from 'express';

/**
 * Risk & Compliance context (ARCHITECTURE.md §4.1).
 * Owns: fraud flags, device blacklist, velocity/limits config.
 * Flags on double-spend (FR-RSK-05); server-configurable limits (FR-RSK-07).
 * Endpoint (§5.6): GET /v1/config.
 * Implemented in a later limits/risk task (outside the demo vertical slice).
 */
export function registerRiskRoutes(router: Router): void {
  router.get('/config', (_req: Request, res: Response) =>
    res.status(501).json({ error: 'NOT_IMPLEMENTED', context: 'risk' }),
  );
}
