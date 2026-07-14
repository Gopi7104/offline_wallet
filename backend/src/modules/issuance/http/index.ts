import { Router } from 'express';

/**
 * Issuance (Mint) context (ARCHITECTURE.md §4.1).
 * Owns: minting coins from bank funds, denomination policy (FR-ISS-02/03/05).
 * Task 2: wallet/load is a simplified balance endpoint (handled by wallet module).
 * Task 5: Token issuance will implement the real coin-minting endpoint here,
 * and migrate wallet/load away from the wallet module.
 * For now, no routes here (to avoid conflicts with wallet during Task 2).
 */
export function registerIssuanceRoutes(_router: Router): void {
  // No routes yet; coins come in Task 5.
}
