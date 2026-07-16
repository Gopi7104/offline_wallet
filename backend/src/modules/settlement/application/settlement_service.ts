import { Money } from '../../../shared/money';
import { Result, ok, err, unwrap } from '../../../shared/result';
import { MerchantRepository } from '../../identity/domain/merchant_repository';
import { LedgerRepository } from '../../ledger/domain/ledger_repository';
import { LedgerEntry } from '../../ledger/domain/ledger_entry';
import { SpentTokenIndex } from '../domain/spent_token_index';
import { SettlementRepository } from '../domain/settlement_repository';
import { SubmittedToken } from '../domain/submitted_token';
import { SettlementResult } from '../domain/settlement_result';
import {
  EmptySettlement,
  UnknownMerchant,
  SettlementError,
} from '../domain/errors';
import { randomUUID } from 'crypto';

/** Parsed, structurally-valid settlement command (built by the controller). */
export interface SettlementCommand {
  readonly merchantId: string;
  readonly tokens: ReadonlyArray<SubmittedToken>;
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

    const now = this.clock();
    const acceptedTokenIds: string[] = [];
    const rejectedTokenIds: string[] = [];
    const duplicateTokenIds: string[] = [];
    let creditedPaise = 0;

    for (const token of command.tokens) {
      // Expired tokens are rejected WITHOUT being claimed — they never
      // consume a slot in the spent-token index (FR-SET, D2 expiry).
      if (token.isExpired(now)) {
        rejectedTokenIds.push(token.tokenId);
        continue;
      }
      // Double-spend enforcement: first claim wins deterministically.
      if (!(await this.spentTokens.tryClaim(token.tokenId))) {
        duplicateTokenIds.push(token.tokenId);
        continue;
      }
      acceptedTokenIds.push(token.tokenId);
      creditedPaise += token.denomination.paise;
    }

    const creditedAmount = unwrap(Money.fromPaise(creditedPaise));
    const status = SettlementResult.deriveStatus(
      acceptedTokenIds.length,
      rejectedTokenIds.length,
      duplicateTokenIds.length,
    );

    // Append ONE immutable ledger entry, hash-chained to the previous one.
    const prevHash = await this.ledger.headHash();
    const entry = LedgerEntry.forSettlement({
      merchantId: command.merchantId,
      amount: creditedAmount,
      acceptedTokenIds,
      rejectedTokenIds,
      duplicateTokenIds,
      status,
      timestamp: now,
      prevHash,
    });
    await this.ledger.append(entry);

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

    return ok(result);
  }
}
