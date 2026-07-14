import { Money } from '../../../shared/money';
import { DomainError } from '../../../shared/errors';
import { Wallet } from '../domain/wallet';
import { WalletRepository } from '../domain/wallet_repository';
import { IssuanceService } from '../../issuance/application/issuance_service';

/**
 * Raised when a load would push the wallet above the holding cap (FR-ISS-06).
 * Mapped to a 400 JSON response by the controller.
 */
export class HoldingCapExceeded extends DomainError {
  readonly code = 'HOLDING_CAP_EXCEEDED';
  constructor(capPaise: number, projectedPaise: number) {
    super(
      `Load rejected: balance would reach ${projectedPaise} paise, above the ` +
        `wallet holding cap of ${capPaise} paise (FR-ISS-06)`,
    );
  }
}

/**
 * WalletService — application layer (use cases). Orchestrates domain logic
 * and persistence (ARCHITECTURE.md §5.1, §6.1). Task 3: now uses IssuanceService
 * to create tokens instead of a numeric balance.
 */
export class WalletService {
  /**
   * FR-ISS-06 holding cap. Per REQUIREMENTS.md the default equals the cumulative
   * offline cap (₹50,000). Server-configurable via the constructor.
   */
  static readonly DEFAULT_MAX_HOLDING_PAISE = 50_000 * 100; // ₹50,000 = 5,000,000 paise

  constructor(
    private readonly walletRepository: WalletRepository,
    private readonly issuanceService: IssuanceService,
    private readonly maxHoldingPaise: number = WalletService.DEFAULT_MAX_HOLDING_PAISE,
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

    // FR-ISS-06: reject a load that would push the wallet above the holding cap.
    // Checked before minting so an over-cap request never creates tokens.
    const projected = wallet.balance.add(amount);
    if (projected.paise > this.maxHoldingPaise) {
      throw new HoldingCapExceeded(this.maxHoldingPaise, projected.paise);
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
