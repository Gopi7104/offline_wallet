import { Wallet } from './wallet';

/**
 * WalletRepository — port (ARCHITECTURE.md §5.1, §5.5: "Domain depends on
 * nothing external; Infrastructure implements ports"). Persistence is the
 * only concern; business logic is in the Wallet aggregate and the service.
 */
export interface WalletRepository {
  findByAccountId(accountId: string): Promise<Wallet | null>;
  save(wallet: Wallet): Promise<void>;
}
