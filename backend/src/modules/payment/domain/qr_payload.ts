import { randomBytes } from 'crypto';

/**
 * QrPayload — payment-QR contents (FR-PAY-01). Wire format matches
 * PAYMENT_PROTOCOL.md §5 exactly: compact keys, epoch-second timestamp, no
 * secret material. This is the JSON the mobile app base64url-encodes into the
 * QR image (§3).
 *
 * Task 4 placeholder: the nonce has no signature and no server-side
 * single-use persistence yet.
 * TODO(Payment full impl): sign the payload and persist consumed nonces for
 * anti-replay + freshness (FR-PAY-08, NFR-SEC-06, §7).
 */
export interface QrPayload {
  v: number;
  typ: 'offer-req';
  mid: string; // merchant_id
  n: string; // base64(16B) single-use nonce
  ts: number; // epoch seconds
  amt?: number; // optional requested amount, in paise
}

/**
 * Build a placeholder payment-QR payload (§5). QR/nonce generation is owned
 * by the Payment context; the merchant-facing endpoint in the Identity
 * context delegates here. No cryptography in Task 4.
 */
export function buildQrPayload(
  merchantId: string,
  now: Date,
  amountPaise?: number,
): QrPayload {
  const payload: QrPayload = {
    v: 1,
    typ: 'offer-req',
    mid: merchantId,
    n: randomBytes(16).toString('base64'),
    ts: Math.floor(now.getTime() / 1000),
  };
  if (amountPaise !== undefined) {
    payload.amt = amountPaise;
  }
  return payload;
}
