import { Router } from 'express';
import { WalletService } from '../application/wallet_service';
import { WalletRepository } from '../domain/wallet_repository';
import { PgWalletRepository } from '../infra/pg_wallet_repository';
import { WalletController } from './wallet_controller';
import { IssuanceService } from '../../issuance/application/issuance_service';
import { TokenRepository } from '../../issuance/domain/token_repository';
import { PgTokenRepository } from '../../issuance/infra/pg_token_repository';
import { getPool } from '../../../platform/db';

/**
 * Wallet (server shadow) context (ARCHITECTURE.md §4.1, §8).
 * PostgreSQL-backed by default (migrations 002/003); repositories are
 * injectable so tests can swap in an in-memory double.
 * GET /wallet and POST /wallet/load remain the same external API.
 */
export function registerWalletRoutes(
  router: Router,
  deps?: { tokenRepository?: TokenRepository; walletRepository?: WalletRepository },
): void {
  const tokenRepository = deps?.tokenRepository ?? new PgTokenRepository(getPool());
  const walletRepository = deps?.walletRepository ?? new PgWalletRepository(getPool());

  const issuanceService = new IssuanceService(tokenRepository);
  const walletService = new WalletService(walletRepository, issuanceService);
  const controller = new WalletController(walletService);

  // Endpoints: external API is identical to Task 2.
  router.get('/wallet', (req, res) => controller.getWallet(req, res));
  router.post('/wallet/load', (req, res) => controller.loadWallet(req, res));

  // Stub: sync (later task).
  router.post('/wallet/sync', (_req, res) =>
    res.status(501).json({ error: 'NOT_IMPLEMENTED', context: 'wallet.sync' }),
  );

  // Test helpers (temporary).
  (router as any).__walletRepository = walletRepository;
  (router as any).__tokenRepository = tokenRepository;
}
