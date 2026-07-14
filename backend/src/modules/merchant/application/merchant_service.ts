import { Merchant } from '../domain/merchant';
import { MerchantRepository } from '../domain/merchant_repository';
import { randomUUID } from 'crypto';

/**
 * QrPayload — placeholder payment-QR contents (FR-PAY-01). Shape matches the
 * frozen wire contract {v, merchant_id, nonce, ts, amount?} and carries NO
 * secret material. Task 4 is a placeholder only: the nonce is a plain random
 * value with no server-side persistence or signature. Single-use nonce
 * tracking, freshness binding and signing land with the offline payment
 * protocol (a later task).
 */
export interface QrPayload {
  v: number;
  merchantId: string;
  nonce: string;
  ts: string; // ISO-8601 timestamp
  amountPaise?: number; // optional requested amount, in paise
}

/**
 * MerchantService — application layer for Merchant Mode (FR-MER-01/02).
 * Orchestrates the Merchant aggregate and its repository. No cryptography,
 * BLE, QR scanning, settlement or offline transfer here (Task 4 scope).
 */
export class MerchantService {
  constructor(
    private readonly repository: MerchantRepository,
    private readonly clock: () => Date = () => new Date(),
  ) {}

  /**
   * Enable Merchant Mode for an account (FR-MER-01). Idempotent: an account
   * already in Merchant Mode keeps its existing Merchant ID and wallet, so a
   * repeated toggle never mints a second identity.
   */
  async enableMerchantMode(accountId: string, displayName?: string): Promise<Merchant> {
    const existing = await this.repository.findByAccountId(accountId);
    if (existing) return existing;

    const merchant = Merchant.create(
      accountId,
      displayName ?? `Merchant ${accountId}`,
      this.clock(),
    );
    await this.repository.save(merchant);
    return merchant;
  }

  /** Fetch the merchant dashboard state for an account (null if not enabled). */
  async getByAccountId(accountId: string): Promise<Merchant | null> {
    return this.repository.findByAccountId(accountId);
  }

  /**
   * Generate a placeholder payment-QR payload (FR-PAY-01). Returns null if the
   * account is not in Merchant Mode (the caller maps that to 404).
   */
  async generateQrPayload(accountId: string, amountPaise?: number): Promise<QrPayload | null> {
    const merchant = await this.repository.findByAccountId(accountId);
    if (!merchant) return null;

    const payload: QrPayload = {
      v: 1,
      merchantId: merchant.merchantId,
      nonce: randomUUID(),
      ts: this.clock().toISOString(),
    };
    if (amountPaise !== undefined) {
      payload.amountPaise = amountPaise;
    }
    return payload;
  }
}
