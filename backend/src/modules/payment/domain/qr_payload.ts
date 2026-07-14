import { randomUUID } from 'crypto';

/**
 * QrPayload — payment-QR contents (FR-PAY-01, §7). The `nonce` is the Payment
 * context's single-use challenge value object (§4.2). Mirrors the frozen wire
 * contract {v, merchant_id, nonce, ts, amount?} and carries NO secret material.
 *
 * Task 4 placeholder: the nonce is a plain random value with no signature and
 * no server-side single-use persistence.
 * TODO(Payment full impl): sign the payload and persist consumed nonces for
 * anti-replay + freshness (FR-PAY-08, NFR-SEC-06, §7).
 */
export interface QrPayload {
  v: number;
  merchantId: string;
  nonce: string;
  ts: string; // ISO-8601 timestamp
  amountPaise?: number; // optional requested amount, in paise
}

/**
 * Build a placeholder payment-QR payload. QR/nonce generation is owned by the
 * Payment context (§4.2 Nonce, §7); the merchant-facing endpoint in the
 * Identity context delegates here. No cryptography in Task 4.
 */
export function buildQrPayload(
  merchantId: string,
  now: Date,
  amountPaise?: number,
): QrPayload {
  const payload: QrPayload = {
    v: 1,
    merchantId,
    nonce: randomUUID(),
    ts: now.toISOString(),
  };
  if (amountPaise !== undefined) {
    payload.amountPaise = amountPaise;
  }
  return payload;
}
