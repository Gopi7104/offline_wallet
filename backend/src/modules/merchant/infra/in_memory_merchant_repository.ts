import { Merchant } from '../domain/merchant';
import { MerchantRepository } from '../domain/merchant_repository';

/**
 * InMemoryMerchantRepository — adapter for Task 4 (before PostgreSQL).
 * Indexes by both accountId (one merchant per account) and merchantId.
 */
export class InMemoryMerchantRepository implements MerchantRepository {
  private byAccount = new Map<string, Merchant>();
  private byMerchantId = new Map<string, Merchant>();

  async findByAccountId(accountId: string): Promise<Merchant | null> {
    return this.byAccount.get(accountId) ?? null;
  }

  async findByMerchantId(merchantId: string): Promise<Merchant | null> {
    return this.byMerchantId.get(merchantId) ?? null;
  }

  async save(merchant: Merchant): Promise<void> {
    this.byAccount.set(merchant.accountId, merchant);
    this.byMerchantId.set(merchant.merchantId, merchant);
  }

  /** Test helper: clear all merchants. */
  clear(): void {
    this.byAccount.clear();
    this.byMerchantId.clear();
  }
}
