import { Router } from 'express';
import { MerchantService } from '../application/merchant_service';
import { InMemoryMerchantRepository } from '../infra/in_memory_merchant_repository';
import { MerchantController } from './merchant_controller';

/**
 * Merchant Mode context (FR-MER-01/02, ARCHITECTURE.md §4.1).
 * Task 4 (vertical slice): enable Merchant Mode (mint Merchant ID + merchant
 * wallet), read the merchant dashboard, and generate a placeholder payment QR
 * payload. BLE, QR scanning, settlement, cryptography and offline transfer are
 * out of scope here and land in later tasks.
 */
export function registerMerchantRoutes(router: Router): void {
  // Composition root: in-memory repository for Task 4 (swap for PostgreSQL later).
  const repository = new InMemoryMerchantRepository();
  const service = new MerchantService(repository);
  const controller = new MerchantController(service);

  router.post('/merchant/enable', (req, res) => controller.enable(req, res));
  router.get('/merchant', (req, res) => controller.getDashboard(req, res));
  router.post('/merchant/qr', (req, res) => controller.generateQr(req, res));

  // Test helper (temporary), consistent with the wallet context.
  (router as any).__merchantRepository = repository;
}
