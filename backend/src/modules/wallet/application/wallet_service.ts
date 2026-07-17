import { Money } from '../../../shared/money';
import { DomainError } from '../../../shared/errors';
import { Wallet } from '../domain/wallet';
import { WalletRepository } from '../domain/wallet_repository';
import { IssuanceService } from '../../issuance/application/issuance_service';
import { Token } from '../../issuance/domain/token';
import { RiskEngine } from '../../risk/application/risk_engine';
import { logger } from '../../../platform/logger';

/** Result of a successful load: the new balance and the exact tokens just issued. */
export interface LoadResult {
  readonly balance: Money;
  readonly tokens: Token[];
}

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
    // Optional: when provided, the wallet-balance decision is delegated to
    // the Risk & Compliance context (production hardening §2) instead of the
    // raw `maxHoldingPaise` comparison below — "risk decisions must remain
    // inside the Risk bounded context". Omitted by every existing caller/test
    // that predates the Risk engine; the real composition root
    // (wallet/http/index.ts) always supplies one.
    private readonly riskEngine?: RiskEngine,
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
   * Creates fine-denomination tokens via IssuanceService, each signed by the
   * issuer. Bank debit is simulated; ledger entry comes in Task 5.
   *
   * Returns the new balance AND the exact tokens just issued (Task 10 —
   * connects the real backend-issued, Ed25519-signed tokens to the mobile
   * wallet; previously only the balance was returned and the mobile app
   * substituted locally-minted placeholder tokens instead). The returned
   * tokens carry the SAME tokenId/denomination/issuedAt/expiry/signature
   * that `issuanceService.issueTokens` produced — only `status` is advanced
   * to `'in_wallet'` (mirroring `Wallet.addTokens`'s own transition), so what
   * the caller receives matches exactly what was just persisted.
   */
  async loadWallet(accountId: string, amount: Money): Promise<LoadResult> {
    // Fetch or create wallet.
    let wallet = await this.walletRepository.findByAccountId(accountId);
    if (!wallet) {
      wallet = Wallet.empty(accountId);
    }

    // FR-ISS-06: reject a load that would push the wallet above the holding cap.
    // Checked before minting so an over-cap request never creates tokens.
    const projected = wallet.balance.add(amount);
    const decision = this.riskEngine
      ? this.riskEngine.checkWalletBalance(projected.paise)
      : { allowed: projected.paise <= this.maxHoldingPaise };
    if (!decision.allowed) {
      logger.warn('wallet.holding_cap_exceeded', { accountId, projectedPaise: projected.paise });
      throw new HoldingCapExceeded(this.maxHoldingPaise, projected.paise);
    }

    // Issue tokens for the requested amount.
    const tokens = await this.issuanceService.issueTokens(accountId, amount);

    // Add tokens to wallet (transitions each minted -> in_wallet internally).
    wallet = wallet.addTokens(tokens);

    // Persist.
    await this.walletRepository.save(wallet);
    logger.info('wallet.loaded', { accountId, amountPaise: amount.paise, newBalancePaise: wallet.balance.paise });

    const issuedTokens = tokens.map((t) => t.withStatus('in_wallet'));
    return { balance: wallet.balance, tokens: issuedTokens };
  }
}
