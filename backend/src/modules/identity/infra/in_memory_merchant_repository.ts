import { MerchantProfile } from '../domain/merchant_profile';
import { MerchantRepository } from '../domain/merchant_repository';

/**
 * InMemoryMerchantRepository — adapter for Task 4 (before PostgreSQL).
 * Indexes by both accountId (one profile per account) and merchantId.
 */
export class InMemoryMerchantRepository implements MerchantRepository {
  private byAccount = new Map<string, MerchantProfile>();
  private byMerchantId = new Map<string, MerchantProfile>();

  async findByAccountId(accountId: string): Promise<MerchantProfile | null> {
    return this.byAccount.get(accountId) ?? null;
  }

  async findByMerchantId(merchantId: string): Promise<MerchantProfile | null> {
    return this.byMerchantId.get(merchantId) ?? null;
  }

  async save(profile: MerchantProfile): Promise<void> {
    this.byAccount.set(profile.accountId, profile);
    this.byMerchantId.set(profile.merchantId, profile);
  }

  /** Test helper: clear all merchant profiles. */
  clear(): void {
    this.byAccount.clear();
    this.byMerchantId.clear();
  }
}
