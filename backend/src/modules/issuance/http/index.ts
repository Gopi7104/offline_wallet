import { Router, Request, Response } from 'express';

/**
 * Issuance (Mint) context (ARCHITECTURE.md §4.1).
 * Owns: minting coins from bank funds, denomination policy.
 * Atomic debit + mint + ledger entry (FR-ISS-02); expiry (FR-ISS-05).
 * Endpoint (§5.6): POST /v1/wallet/load.
 * Implemented in the Token issuance task.
 */
export function registerIssuanceRoutes(router: Router): void {
  router.post('/wallet/load', (_req: Request, res: Response) =>
    res.status(501).json({ error: 'NOT_IMPLEMENTED', context: 'issuance' }),
  );
}
