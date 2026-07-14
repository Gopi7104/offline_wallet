import { Router, Request, Response } from 'express';
import { MerchantService } from '../application/merchant_service';
import { MerchantRepository } from '../domain/merchant_repository';
import { InMemoryMerchantRepository } from '../infra/in_memory_merchant_repository';
import { MerchantController } from './merchant_controller';

/**
 * Identity & Device context (ARCHITECTURE.md §4.1).
 * Owns: accounts, device bindings, one-active-device (FR-ID-04),
 * Firebase token → session (FR-ID-01), and the Merchant *role* on an account
 * (Merchant Mode, FR-MER-01 — "a user is a Customer and, in Merchant Mode, a
 * Merchant", §4.1). QR/nonce generation is owned by the Payment context and
 * delegated to it (§4.2, §7).
 * Endpoints (§5.6): POST /v1/auth/session, POST /v1/devices/register.
 * auth/device flows implemented in the Authentication task.
 */
export function registerIdentityRoutes(
  router: Router,
  deps?: { merchantRepository?: MerchantRepository },
): void {
  const notImplemented = (_req: Request, res: Response) =>
    res.status(501).json({ error: 'NOT_IMPLEMENTED', context: 'identity' });

  router.post('/auth/session', notImplemented);
  router.post('/devices/register', notImplemented);

  // Merchant Mode (FR-MER-01/02). Absorbed from the Task 4 standalone module
  // into Identity per the Architecture v1.1 review: Merchant is a role on
  // Account, not its own bounded context. Public API unchanged. The repository
  // is injected by the composition root so the Payment context can validate
  // against the same merchant store (Task 5).
  const merchantRepository = deps?.merchantRepository ?? new InMemoryMerchantRepository();
  const merchantService = new MerchantService(merchantRepository);
  const merchantController = new MerchantController(merchantService);

  router.post('/merchant/enable', (req, res) => merchantController.enable(req, res));
  router.get('/merchant', (req, res) => merchantController.getDashboard(req, res));
  router.post('/merchant/qr', (req, res) => merchantController.generateQr(req, res));

  // Test helper (temporary), consistent with the wallet context.
  (router as any).__merchantRepository = merchantRepository;
}
