import { MerchantProfile } from '../domain/merchant_profile';
import { MerchantRepository } from '../domain/merchant_repository';

/**
 * MerchantService — Merchant Mode use cases (FR-MER-01/02). Part of the
 * Identity & Device context: Merchant is a role on Account (§4.1), not a
 * separate bounded context. No cryptography, BLE, QR scanning, settlement or
 * offline transfer here (Task 4 scope). QR generation for a payment request
 * is owned entirely by the mobile app's offline BLE flow (Receive Payment) —
 * there is no backend-generated QR anymore.
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
}
