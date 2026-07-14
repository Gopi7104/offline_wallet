import { Router } from 'express';
import { WalletService } from '../application/wallet_service';
import { InMemoryWalletRepository } from '../infra/in_memory_wallet_repository';
import { WalletController } from './wallet_controller';
import { IssuanceService } from '../../issuance/application/issuance_service';
import { InMemoryTokenRepository } from '../../issuance/infra/in_memory_token_repository';

/**
 * Wallet (server shadow) context (ARCHITECTURE.md §4.1, §8).
 * Task 3: Wallet now stores digital cash tokens; balance is computed from them.
 * GET /wallet and POST /wallet/load remain the same external API.
 */
export function registerWalletRoutes(router: Router): void {
  // Composition root: in-memory repositories for Task 3.
  // Later tasks: swap for PostgreSQL.
  const tokenRepository = new InMemoryTokenRepository();
  const walletRepository = new InMemoryWalletRepository();

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
