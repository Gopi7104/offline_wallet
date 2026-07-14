import { Router } from 'express';

/**
 * Payment / Transfer context (ARCHITECTURE.md §4.1, §7).
 * Owns: verification of owner-signed transfers uploaded at settlement —
 * signatures, nonce, freshness (FR-PAY-04/05), single-hop (D1).
 * No standalone online endpoint: the payment path is offline (BLE/QR);
 * transfers reach the server via the settlement redeem batch.
 * Domain logic implemented in the Offline transfer task.
 */
export function registerPaymentRoutes(_router: Router): void {
  // Intentionally no HTTP routes — offline-only context.
}
