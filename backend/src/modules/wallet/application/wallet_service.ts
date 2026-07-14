import { Money } from '../../../shared/money';
import { Wallet } from '../domain/wallet';
import { WalletRepository } from '../domain/wallet_repository';
import { IssuanceService } from '../../issuance/application/issuance_service';

/**
 * WalletService — application layer (use cases). Orchestrates domain logic
 * and persistence (ARCHITECTURE.md §5.1, §6.1). Task 3: now uses IssuanceService
 * to create tokens instead of a numeric balance.
 */
export class WalletService {
  constructor(
    private readonly walletRepository: WalletRepository,
    private readonly issuanceService: IssuanceService,
  ) {}

  /**
   * Get the current wallet balance (computed from tokens).
   */
  async getBalance(accountId: string): Promise<Money | null> {
    const wallet = await this.walletRepository.findByAccountId(accountId);
    return wallet?.balance ?? null;
  }

  /**
   * Load wallet with digital cash tokens (ARCHITECTURE.md §4.2, §4.3, FR-ISS-02).
   * Task 3: creates fine-denomination tokens via IssuanceService.
   * Bank debit is simulated; ledger entry comes in Task 5.
   * Returns the new balance (sum of token denominations).
   */
  async loadWallet(accountId: string, amount: Money): Promise<Money> {
    // Fetch or create wallet.
    let wallet = await this.walletRepository.findByAccountId(accountId);
    if (!wallet) {
      wallet = Wallet.empty(accountId);
    }

    // Issue tokens for the requested amount.
    const tokens = await this.issuanceService.issueTokens(accountId, amount);

    // Add tokens to wallet.
    wallet = wallet.addTokens(tokens);

    // Persist.
    await this.walletRepository.save(wallet);
    return wallet.balance;
  }
}
