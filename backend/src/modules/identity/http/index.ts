import { Router, Request, Response } from 'express';
import { MerchantService } from '../application/merchant_service';
import { MerchantRepository } from '../domain/merchant_repository';
import { PgMerchantRepository } from '../infra/pg_merchant_repository';
import { MerchantController } from './merchant_controller';
import { getPool } from '../../../platform/db';

/**
 * Identity & Device context (ARCHITECTURE.md §4.1).
 * Owns: accounts, device bindings, one-active-device (FR-ID-04),
 * Firebase token → session (FR-ID-01), and the Merchant *role* on an account
 * (Merchant Mode, FR-MER-01 — "a user is a Customer and, in Merchant Mode, a
 * Merchant", §4.1). QR/nonce generation is owned by the Payment context and
 * delegated to it (§4.2, §7).
 * Endpoints (§5.6): POST /v1/auth/session, POST /v1/devices/register.
 * /auth/session is implemented (FR-ID-01, this task); device binding
 * (FR-ID-02/03/04) stays a 501 stub until the Device Key task lands.
 */
export function registerIdentityRoutes(
  router: Router,
  deps?: { merchantRepository?: MerchantRepository },
): void {
  const notImplemented = (_req: Request, res: Response) =>
    res.status(501).json({ error: 'NOT_IMPLEMENTED', context: 'identity' });

  // Exchange a Firebase ID token for a backend session (FR-ID-01).
  // `resolveAccountId` (mounted ahead of every /v1 route) already verified
  // the token via the Firebase Admin SDK and rejected anything invalid,
  // expired, or revoked with 401 before this handler runs — it only needs
  // to check that a *real* token was presented, not a Guest Mode fallback
  // (Guest Mode has no Firebase session to exchange).
  router.post('/auth/session', (req: Request, res: Response) => {
    if (!req.firebaseUser) {
      res.status(401).json({
        error: 'MISSING_TOKEN',
        message: 'A valid Firebase ID token is required (Authorization: Bearer <idToken>)',
      });
      return;
    }
    res.status(200).json({
      accountId: req.firebaseUser.uid,
      firebaseUid: req.firebaseUser.uid,
      email: req.firebaseUser.email ?? null,
    });
  });
  router.post('/devices/register', notImplemented);

  // Merchant Mode (FR-MER-01/02). Absorbed from the Task 4 standalone module
  // into Identity per the Architecture v1.1 review: Merchant is a role on
  // Account, not its own bounded context. Public API unchanged. The repository
  // is injected by the composition root so the Payment context can validate
  // against the same merchant store (Task 5).
  const merchantRepository = deps?.merchantRepository ?? new PgMerchantRepository(getPool());
  const merchantService = new MerchantService(merchantRepository);
  const merchantController = new MerchantController(merchantService);

  router.post('/merchant/enable', (req, res) => merchantController.enable(req, res));
  router.get('/merchant', (req, res) => merchantController.getDashboard(req, res));
  router.post('/merchant/qr', (req, res) => merchantController.generateQr(req, res));

  // Test helper (temporary), consistent with the wallet context.
  (router as any).__merchantRepository = merchantRepository;
}
