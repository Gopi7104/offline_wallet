import { MerchantProfile, MerchantWallet } from '../domain/merchant_profile';
import { MerchantRepository } from '../domain/merchant_repository';
import { SettlementRepository } from '../../settlement/domain/settlement_repository';

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
    // Optional: the Settlement context owns the authoritative settled balance
    // (merchant_profiles.settled_paise is a stale placeholder, see
    // merchant_profile.ts's MerchantWallet doc comment). Undefined preserves
    // the old always-zero behavior for callers that don't wire it up (tests).
    private readonly settlementRepository?: SettlementRepository,
  ) {}

  /**
   * Enable Merchant Mode for an account (FR-MER-01). Idempotent: an account
   * already in Merchant Mode keeps its existing Merchant ID and wallet, so a
   * repeated toggle never mints a second identity.
   */
  async enableMerchantMode(accountId: string, displayName?: string): Promise<MerchantProfile> {
    const existing = await this.repository.findByAccountId(accountId);
    if (existing) return this.withSettledBalance(existing);

    const profile = MerchantProfile.create(
      accountId,
      displayName ?? `Merchant ${accountId}`,
      this.clock(),
    );
    await this.repository.save(profile);
    return this.withSettledBalance(profile);
  }

  /** Fetch the merchant dashboard state for an account (null if not enabled). */
  async getByAccountId(accountId: string): Promise<MerchantProfile | null> {
    const profile = await this.repository.findByAccountId(accountId);
    return profile ? this.withSettledBalance(profile) : null;
  }

  /** Overlay the real settled balance (Settlement context) onto the profile. */
  private async withSettledBalance(profile: MerchantProfile): Promise<MerchantProfile> {
    if (!this.settlementRepository) return profile;
    const settled = await this.settlementRepository.settledBalance(profile.merchantId);
    return new MerchantProfile(
      profile.merchantId,
      profile.accountId,
      profile.displayName,
      new MerchantWallet(profile.wallet.pendingSettlement, settled),
      profile.createdAt,
    );
  }
}
