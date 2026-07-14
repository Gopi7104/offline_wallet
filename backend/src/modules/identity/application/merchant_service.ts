import { MerchantProfile } from '../domain/merchant_profile';
import { MerchantRepository } from '../domain/merchant_repository';
import { QrPayload, buildQrPayload } from '../../payment/domain/qr_payload';

/**
 * MerchantService — Merchant Mode use cases (FR-MER-01/02). Part of the
 * Identity & Device context: Merchant is a role on Account (§4.1), not a
 * separate bounded context. QR/nonce generation is delegated to the Payment
 * context (§4.2, §7). No cryptography, BLE, QR scanning, settlement or offline
 * transfer here (Task 4 scope).
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
  async enableMerchantMode(accountId: string, displayName?: string): Promise<MerchantProfile> {
    const existing = await this.repository.findByAccountId(accountId);
    if (existing) return existing;

    const profile = MerchantProfile.create(
      accountId,
      displayName ?? `Merchant ${accountId}`,
      this.clock(),
    );
    await this.repository.save(profile);
    return profile;
  }

  /** Fetch the merchant dashboard state for an account (null if not enabled). */
  async getByAccountId(accountId: string): Promise<MerchantProfile | null> {
    return this.repository.findByAccountId(accountId);
  }

  /**
   * Generate a placeholder payment-QR payload (FR-PAY-01). Returns null if the
   * account is not in Merchant Mode (the caller maps that to 404). The payload
   * shape and nonce are owned by the Payment context (delegated to
   * buildQrPayload).
   */
  async generateQrPayload(accountId: string, amountPaise?: number): Promise<QrPayload | null> {
    const profile = await this.repository.findByAccountId(accountId);
    if (!profile) return null;
    return buildQrPayload(profile.merchantId, this.clock(), amountPaise);
  }
}
