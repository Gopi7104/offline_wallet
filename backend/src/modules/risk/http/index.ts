import { Router, Request, Response } from 'express';
import { loadConfig } from '../../../platform/config';

/**
 * Risk & Compliance context (ARCHITECTURE.md §4.1; production hardening §2).
 * Owns: risk-rule decisions (application/risk_engine.ts), fraud flags
 * (domain/risk_flag.ts). GET /v1/config exposes the current server-driven
 * limits (FR-RSK-07 "server-configurable without an app release") so the
 * mobile app can enforce the same thresholds client-side before going
 * offline — never secrets, just the numeric policy.
 */
export function registerRiskRoutes(router: Router): void {
  router.get('/config', (_req: Request, res: Response) => {
    const { risk } = loadConfig();
    res.status(200).json({ risk });
  });
}
