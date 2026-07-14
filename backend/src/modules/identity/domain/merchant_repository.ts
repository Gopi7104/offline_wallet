import { MerchantProfile } from './merchant_profile';

/**
 * MerchantRepository — port (ARCHITECTURE.md §5.1, §5.5). Part of the Identity
 * & Device context: a merchant profile is a role on an account, so there is one
 * profile per account (FR-MER-01). Domain defines the interface; infrastructure
 * implements it.
 */
export interface MerchantRepository {
  findByAccountId(accountId: string): Promise<MerchantProfile | null>;
  findByMerchantId(merchantId: string): Promise<MerchantProfile | null>;
  save(profile: MerchantProfile): Promise<void>;
}
