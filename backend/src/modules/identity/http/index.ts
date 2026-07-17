import { Router, Request, Response } from 'express';
import { MerchantService } from '../application/merchant_service';
import { MerchantRepository } from '../domain/merchant_repository';
import { DeviceRepository } from '../domain/device_repository';
import { SettlementRepository } from '../../settlement/domain/settlement_repository';
import { PgMerchantRepository } from '../infra/pg_merchant_repository';
import { PgDeviceRepository } from '../infra/pg_device_repository';
import { PgSettlementRepository } from '../../settlement/infra/pg_settlement_repository';
import { MerchantController } from './merchant_controller';
import { DeviceController } from './device_controller';
import { DeviceService } from '../application/device_service';
import { getPool } from '../../../platform/db';

/**
 * Identity & Device context (ARCHITECTURE.md §4.1).
 * Owns: accounts, device registration (inventory — production hardening §1),
 * Firebase token → session (FR-ID-01), and the Merchant *role* on an account
 * (Merchant Mode, FR-MER-01 — "a user is a Customer and, in Merchant Mode, a
 * Merchant", §4.1). Payment-request QR generation is fully offline, owned by
 * the mobile app's BLE Receive Payment flow — there is no backend QR endpoint.
 * Endpoints (§5.6): POST /v1/auth/session, POST /v1/devices/register.
 * /auth/session is implemented (FR-ID-01). Device registration here is the
 * operational inventory (id/platform/model/app version/last-seen), NOT the
 * full cryptographic device-binding feature (FR-ID-02/03/04, one-active-device
 * enforcement) — that remains a documented future item (docs/TODO.md).
 */
export function registerIdentityRoutes(
  router: Router,
  deps?: {
    merchantRepository?: MerchantRepository;
    deviceRepository?: DeviceRepository;
    settlementRepository?: SettlementRepository;
  },
): void {
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

  // Device registration (production hardening §1).
  const deviceRepository = deps?.deviceRepository ?? new PgDeviceRepository(getPool());
  const deviceService = new DeviceService(deviceRepository);
  const deviceController = new DeviceController(deviceService);

  router.post('/devices/register', (req, res) => deviceController.register(req, res));
  router.post('/devices/:deviceId/last-seen', (req, res) => deviceController.touchLastSeen(req, res));
  router.get('/devices', (req, res) => deviceController.list(req, res));

  // Test helper (temporary), consistent with the merchant/wallet contexts.
  (router as any).__deviceRepository = deviceRepository;

  // Merchant Mode (FR-MER-01/02). Absorbed from the Task 4 standalone module
  // into Identity per the Architecture v1.1 review: Merchant is a role on
  // Account, not its own bounded context. Public API unchanged. The repository
  // is injected by the composition root so the Payment context can validate
  // against the same merchant store (Task 5).
  const merchantRepository = deps?.merchantRepository ?? new PgMerchantRepository(getPool());
  // Settlement owns the authoritative settled balance (merchant_settlement_balances);
  // merchant_profiles.settled_paise is a stale placeholder (merchant_profile.ts).
  const settlementRepository = deps?.settlementRepository ?? new PgSettlementRepository(getPool());
  const merchantService = new MerchantService(merchantRepository, undefined, settlementRepository);
  const merchantController = new MerchantController(merchantService);

  router.post('/merchant/enable', (req, res) => merchantController.enable(req, res));
  router.get('/merchant', (req, res) => merchantController.getDashboard(req, res));

  // Test helper (temporary), consistent with the wallet context.
  (router as any).__merchantRepository = merchantRepository;
}
