import { RiskLimitsConfig } from '../../../platform/config';
import { RiskDecision, ALLOWED } from '../domain/risk_decision';
import { RiskFlag } from '../domain/risk_flag';
import { PayerActivityRepository } from '../domain/payer_activity_repository';
import { RiskFlagRepository } from '../domain/risk_flag_repository';

function hours(n: number): number {
  return n * 3_600_000;
}
function minutes(n: number): number {
  return n * 60_000;
}

/**
 * RiskEngine — the Risk & Compliance context's application service
 * (ARCHITECTURE.md §4.1, FR-RSK-01/02/06/07; production hardening §2).
 * Every configurable limit lives here, sourced from `RiskLimitsConfig`
 * (platform/config.ts) — Wallet and Settlement ask this service for a
 * decision; neither reimplements a threshold comparison itself.
 *
 * Duplicate-payment detection and expired-token rejection (also listed in
 * the hardening brief) are pre-existing Settlement domain invariants
 * (spent-token unique index; Token.isExpired) — those remain in Settlement,
 * which owns the state they check (bounded-context ownership), and are not
 * duplicated here.
 */
export class RiskEngine {
  constructor(
    private readonly limits: RiskLimitsConfig,
    private readonly payerActivity: PayerActivityRepository,
    private readonly riskFlags: RiskFlagRepository,
  ) {}

  /** FR-RSK: max value a wallet may hold offline. Pure — no I/O. */
  checkWalletBalance(projectedBalancePaise: number): RiskDecision {
    if (projectedBalancePaise > this.limits.maxOfflineWalletBalancePaise) {
      return {
        allowed: false,
        reasonCode: 'MAX_WALLET_BALANCE_EXCEEDED',
        message: `Projected balance ${projectedBalancePaise} paise exceeds the offline wallet cap of ${this.limits.maxOfflineWalletBalancePaise} paise`,
      };
    }
    return ALLOWED;
  }

  /** FR-RSK-01: max value of a single offline payment. Pure — no I/O. */
  checkSinglePayment(amountPaise: number): RiskDecision {
    if (amountPaise > this.limits.maxSingleOfflinePaymentPaise) {
      return {
        allowed: false,
        reasonCode: 'MAX_SINGLE_PAYMENT_EXCEEDED',
        message: `Payment of ${amountPaise} paise exceeds the per-transaction cap of ${this.limits.maxSingleOfflinePaymentPaise} paise`,
      };
    }
    return ALLOWED;
  }

  /** FR-RSK-02: cumulative value settled for this payer within the rolling window. */
  async checkCumulativeSpending(accountId: string, amountPaise: number, now: Date): Promise<RiskDecision> {
    const since = new Date(now.getTime() - hours(this.limits.cumulativeWindowHours));
    const spentSoFar = await this.payerActivity.sumSince(accountId, since);
    if (spentSoFar + amountPaise > this.limits.maxCumulativeOfflinePaise) {
      return {
        allowed: false,
        reasonCode: 'MAX_CUMULATIVE_OFFLINE_EXCEEDED',
        message: `Cumulative offline spend would reach ${spentSoFar + amountPaise} paise, above the ${this.limits.cumulativeWindowHours}h cap of ${this.limits.maxCumulativeOfflinePaise} paise`,
      };
    }
    return ALLOWED;
  }

  /** Daily transaction count safety net (a longer, higher-count window than velocity). */
  async checkDailyTransactionCount(accountId: string, now: Date): Promise<RiskDecision> {
    const since = new Date(now.getTime() - hours(this.limits.dailyWindowHours));
    const countSoFar = await this.payerActivity.countSince(accountId, since);
    if (countSoFar + 1 > this.limits.maxDailyTransactionCount) {
      return {
        allowed: false,
        reasonCode: 'MAX_DAILY_TX_COUNT_EXCEEDED',
        message: `This would be transaction ${countSoFar + 1} in the last ${this.limits.dailyWindowHours}h, above the cap of ${this.limits.maxDailyTransactionCount}`,
      };
    }
    return ALLOWED;
  }

  /** Velocity: a shorter burst window, distinct from the daily count above. */
  async checkVelocity(accountId: string, now: Date): Promise<RiskDecision> {
    const since = new Date(now.getTime() - minutes(this.limits.velocityWindowMinutes));
    const countSoFar = await this.payerActivity.countSince(accountId, since);
    if (countSoFar + 1 > this.limits.velocityMaxCount) {
      return {
        allowed: false,
        reasonCode: 'VELOCITY_LIMIT_EXCEEDED',
        message: `This would be transaction ${countSoFar + 1} in the last ${this.limits.velocityWindowMinutes}m, above the velocity cap of ${this.limits.velocityMaxCount}`,
      };
    }
    return ALLOWED;
  }

  /**
   * Evaluate an offline payment against every rule that requires payer
   * history (single-payment cap first — cheapest, no I/O — then velocity,
   * daily count, cumulative). Returns the first rejection; raises a RiskFlag
   * against the payer account for any rejection (FR-RSK-06).
   */
  async evaluateOfflinePayment(accountId: string, amountPaise: number, now: Date): Promise<RiskDecision> {
    const single = this.checkSinglePayment(amountPaise);
    if (!single.allowed) return this.flagAndReturn(accountId, single, now);

    const velocity = await this.checkVelocity(accountId, now);
    if (!velocity.allowed) return this.flagAndReturn(accountId, velocity, now);

    const daily = await this.checkDailyTransactionCount(accountId, now);
    if (!daily.allowed) return this.flagAndReturn(accountId, daily, now);

    const cumulative = await this.checkCumulativeSpending(accountId, amountPaise, now);
    if (!cumulative.allowed) return this.flagAndReturn(accountId, cumulative, now);

    return ALLOWED;
  }

  /** Record an accepted payment so future window queries see it (call only after settlement actually accepts the token). */
  async recordAcceptedPayment(accountId: string, amountPaise: number, now: Date): Promise<void> {
    await this.payerActivity.record(accountId, amountPaise, now);
  }

  private async flagAndReturn(accountId: string, decision: RiskDecision, now: Date): Promise<RiskDecision> {
    await this.riskFlags.raise(
      RiskFlag.raise('account', accountId, decision.reasonCode ?? 'RISK_REJECTED', decision.message ?? '', 'medium', now),
    );
    return decision;
  }
}
