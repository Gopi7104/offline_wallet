import { Money } from '../../../shared/money';
import { Result, ok, err, unwrap } from '../../../shared/result';
import { MerchantRepository } from '../../identity/domain/merchant_repository';
import { LedgerRepository } from '../../ledger/domain/ledger_repository';
import { LedgerEntry } from '../../ledger/domain/ledger_entry';
import { SpentTokenIndex } from '../domain/spent_token_index';
import { SettlementRepository } from '../domain/settlement_repository';
import { SubmittedToken } from '../domain/submitted_token';
import { SettlementResult } from '../domain/settlement_result';
import { TokenVerifier } from '../domain/token_verifier';
import { Ed25519TokenVerifier } from '../infra/ed25519_token_verifier';
import { toEpochSeconds } from '../../../shared/crypto/token_canonical_payload';
import { RiskEngine } from '../../risk/application/risk_engine';
import { logger } from '../../../platform/logger';
import {
  EmptySettlement,
  UnknownMerchant,
  UnauthorizedMerchant,
  SettlementError,
} from '../domain/errors';
import { randomUUID } from 'crypto';

/** Parsed, structurally-valid settlement command (built by the controller). */
export interface SettlementCommand {
  readonly merchantId: string;
  readonly tokens: ReadonlyArray<SubmittedToken>;
  /**
   * The authenticated caller's account id. Optional so direct-service callers
   * (most unit tests) are unaffected; the HTTP controller always supplies
   * `req.accountId` — when present, it must match the merchant's owning
   * account (security review, production hardening §9).
   */
  readonly callerAccountId?: string;
}

/**
 * SettlementService — the Settlement (Redemption) use case (ARCHITECTURE.md
 * §4.1, §5.6; FR-SET-01..05). Validates the merchant, then for each token:
 * checks expiry, then atomically claims it in the SpentTokenIndex. First claim
 * wins (redeemed + credited); any later claim of the same token id is a
 * double-spend and is rejected (TOKEN_ALREADY_SPENT), never credited twice.
 *
 * Every settlement appends exactly one immutable, hash-chained LedgerEntry
 * (§5.4). The merchant's settled balance is credited only by the accepted
 * amount, so a repeat settlement (all duplicates → credited 0) leaves the
 * balance unchanged.
 *
 * Expected failures are returned via Result, not thrown (§11).
 */
export class SettlementService {
  constructor(
    private readonly merchants: MerchantRepository,
    private readonly spentTokens: SpentTokenIndex,
    private readonly ledger: LedgerRepository,
    private readonly settlements: SettlementRepository,
    private readonly clock: () => Date = () => new Date(),
    private readonly tokenVerifier: TokenVerifier = new Ed25519TokenVerifier(),
    // Optional: when provided, per-transaction/cumulative/daily/velocity
    // limits are enforced (production hardening §2) — "risk decisions must
    // remain inside the Risk bounded context". Omitted by callers that
    // predate the Risk engine; the real composition root always supplies one.
    private readonly riskEngine?: RiskEngine,
  ) {}

  async settle(
    command: SettlementCommand,
  ): Promise<Result<SettlementResult, SettlementError>> {
    if (command.tokens.length === 0) {
      return err(new EmptySettlement());
    }

    const merchant = await this.merchants.findByMerchantId(command.merchantId);
    if (!merchant) {
      return err(new UnknownMerchant(command.merchantId));
    }
    if (command.callerAccountId !== undefined && command.callerAccountId !== merchant.accountId) {
      logger.warn('settlement.unauthorized_merchant', {
        merchantId: command.merchantId,
        callerAccountId: command.callerAccountId,
      });
      return err(new UnauthorizedMerchant(command.merchantId));
    }

    const now = this.clock();
    const acceptedTokenIds: string[] = [];
    const rejectedTokenIds: string[] = [];
    const duplicateTokenIds: string[] = [];
    let creditedPaise = 0;

    for (const token of command.tokens) {
      // Cryptographic authenticity FIRST: a forged or tampered token is
      // rejected WITHOUT being claimed, before expiry or double-spend even
      // matter — never trust client-provided verification (Ed25519
      // integration; ARCHITECTURE.md "Issuance owns signing, Settlement owns
      // verification").
      const verified = this.tokenVerifier.verify(
        {
          tokenId: token.tokenId,
          denominationPaise: token.denomination.paise,
          ownerId: token.ownerId,
          issuedAtEpochSeconds: toEpochSeconds(token.issuedAt),
          expiryEpochSeconds: toEpochSeconds(token.expiry),
        },
        token.bankSignature,
      );
      if (!verified) {
        rejectedTokenIds.push(token.tokenId);
        continue;
      }
      // Expired tokens are rejected WITHOUT being claimed — they never
      // consume a slot in the spent-token index (FR-SET, D2 expiry).
      if (token.isExpired(now)) {
        rejectedTokenIds.push(token.tokenId);
        continue;
      }
      // Risk limits (per-transaction/cumulative/daily-count/velocity) —
      // also rejected WITHOUT being claimed, same as expiry/signature above.
      if (this.riskEngine) {
        const decision = await this.riskEngine.evaluateOfflinePayment(token.ownerId, token.denomination.paise, now);
        if (!decision.allowed) {
          logger.warn('risk.rejected', {
            accountId: token.ownerId,
            tokenId: token.tokenId,
            reasonCode: decision.reasonCode,
          });
          rejectedTokenIds.push(token.tokenId);
          continue;
        }
      }
      // Double-spend enforcement: first claim wins deterministically.
      if (!(await this.spentTokens.tryClaim(token.tokenId))) {
        duplicateTokenIds.push(token.tokenId);
        continue;
      }
      acceptedTokenIds.push(token.tokenId);
      creditedPaise += token.denomination.paise;
      if (this.riskEngine) {
        await this.riskEngine.recordAcceptedPayment(token.ownerId, token.denomination.paise, now);
      }
    }

    const creditedAmount = unwrap(Money.fromPaise(creditedPaise));
    const status = SettlementResult.deriveStatus(
      acceptedTokenIds.length,
      rejectedTokenIds.length,
      duplicateTokenIds.length,
    );

    // Append ONE immutable ledger entry, hash-chained to the previous one.
    // Reading the head hash and appending must happen as one atomic step
    // (appendAtomically) — otherwise two concurrent settlements could both
    // read the same head and fork the chain.
    const entry = await this.ledger.appendAtomically((prevHash) =>
      LedgerEntry.forSettlement({
        merchantId: command.merchantId,
        amount: creditedAmount,
        acceptedTokenIds,
        rejectedTokenIds,
        duplicateTokenIds,
        status,
        timestamp: now,
        prevHash,
      }),
    );

    // Credit the merchant (no-op when creditedAmount is zero) and record.
    await this.settlements.creditMerchant(command.merchantId, creditedAmount);

    const result = new SettlementResult(
      `SET-${randomUUID()}`,
      command.merchantId,
      acceptedTokenIds,
      rejectedTokenIds,
      duplicateTokenIds,
      creditedAmount,
      entry.ledgerId,
      status,
      now,
    );
    await this.settlements.record(result);

    logger.info('settlement.completed', {
      settlementId: result.settlementId,
      merchantId: command.merchantId,
      accepted: acceptedTokenIds.length,
      rejected: rejectedTokenIds.length,
      duplicates: duplicateTokenIds.length,
      creditedPaise,
      status,
    });

    return ok(result);
  }
}
