import { Wallet } from '../domain/wallet';
import { WalletRepository } from '../domain/wallet_repository';

/**
 * InMemoryWalletRepository — adapter (temporary, for validation before
 * introducing PostgreSQL). Task 2 uses this; later tasks will swap it
 * for a real repository (§5.2).
 */
export class InMemoryWalletRepository implements WalletRepository {
  private store = new Map<string, Wallet>();

  async findByAccountId(accountId: string): Promise<Wallet | null> {
    return this.store.get(accountId) ?? null;
  }

  async save(wallet: Wallet): Promise<void> {
    this.store.set(wallet.accountId, wallet);
  }

  /** Test helper: clear all wallets. */
  clear(): void {
    this.store.clear();
  }
}
