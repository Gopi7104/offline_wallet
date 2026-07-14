import { Router } from 'express';
import { MerchantRepository } from '../../identity/domain/merchant_repository';
import { PaymentService } from '../application/payment_service';
import { PaymentController } from './payment_controller';

/**
 * Payment / Transfer context (ARCHITECTURE.md §4.1, §7).
 * Owns: verification of owner-signed transfers uploaded at settlement —
 * signatures, nonce, freshness (FR-PAY-04/05), single-hop (D1); and QR/nonce
 * generation (§4.2, delegated to from Identity's Merchant Mode).
 *
 * The real payment path is OFFLINE (BLE/QR). Task 5 adds ONE placeholder online
 * endpoint — POST /v1/payment/request — so the Customer Pay UI can validate a
 * merchant + amount against the backend before the offline protocol exists.
 * No BLE, token transfer, settlement or cryptography here.
 */
export function registerPaymentRoutes(
  router: Router,
  deps: { merchantRepository: MerchantRepository },
): void {
  const paymentService = new PaymentService(deps.merchantRepository);
  const controller = new PaymentController(paymentService);

  router.post('/payment/request', (req, res) => controller.createRequest(req, res));
}
