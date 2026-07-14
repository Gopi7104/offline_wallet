import { Merchant } from './merchant';

/**
 * MerchantRepository — port (ARCHITECTURE.md §5.1, §5.5). Domain defines the
 * interface; infrastructure implements it. One merchant per account (Merchant
 * Mode is a role on an account, FR-MER-01).
 */
export interface MerchantRepository {
  findByAccountId(accountId: string): Promise<Merchant | null>;
  findByMerchantId(merchantId: string): Promise<Merchant | null>;
  save(merchant: Merchant): Promise<void>;
}
