import { Money } from '../../../shared/money';
import { SettlementResult } from '../domain/settlement_result';
import { SettlementRepository } from '../domain/settlement_repository';

/**
 * InMemorySettlementRepository — adapter for Task 9 (before PostgreSQL).
 * Tracks the settled balance per merchant and an append-only list of
 * settlement records.
 */
export class InMemorySettlementRepository implements SettlementRepository {
  private readonly balances = new Map<string, Money>();
  private readonly records = new Map<string, SettlementResult[]>();

  async record(result: SettlementResult): Promise<void> {
    const list = this.records.get(result.merchantId) ?? [];
    list.push(result);
    this.records.set(result.merchantId, list);
  }

  async creditMerchant(merchantId: string, amount: Money): Promise<void> {
    if (amount.isZero()) return;
    const current = this.balances.get(merchantId) ?? Money.zero();
    this.balances.set(merchantId, current.add(amount));
  }

  async settledBalance(merchantId: string): Promise<Money> {
    return this.balances.get(merchantId) ?? Money.zero();
  }

  async historyFor(merchantId: string): Promise<SettlementResult[]> {
    return [...(this.records.get(merchantId) ?? [])];
  }

  /** Test helper. */
  clear(): void {
    this.balances.clear();
    this.records.clear();
  }
}
