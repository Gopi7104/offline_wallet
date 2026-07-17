import { RiskEngine } from '../src/modules/risk/application/risk_engine';
import { InMemoryPayerActivityRepository } from '../src/modules/risk/infra/in_memory_payer_activity_repository';
import { InMemoryRiskFlagRepository } from '../src/modules/risk/infra/in_memory_risk_flag_repository';
import { RiskLimitsConfig } from '../src/platform/config';

const FIXED_NOW = new Date('2026-07-16T10:00:00.000Z');

const LIMITS: RiskLimitsConfig = {
  maxOfflineWalletBalancePaise: 50_000 * 100,
  maxSingleOfflinePaymentPaise: 5_000 * 100,
  maxCumulativeOfflinePaise: 10_000 * 100,
  cumulativeWindowHours: 24,
  maxDailyTransactionCount: 3,
  dailyWindowHours: 24,
  velocityMaxCount: 2,
  velocityWindowMinutes: 10,
};

function buildEngine() {
  const activity = new InMemoryPayerActivityRepository();
  const flags = new InMemoryRiskFlagRepository();
  const engine = new RiskEngine(LIMITS, activity, flags);
  return { engine, activity, flags };
}

describe('RiskEngine (application, production hardening §2)', () => {
  describe('checkWalletBalance (FR-RSK: max offline wallet balance)', () => {
    it('allows a projected balance at or below the cap', () => {
      const { engine } = buildEngine();
      expect(engine.checkWalletBalance(LIMITS.maxOfflineWalletBalancePaise).allowed).toBe(true);
    });

    it('rejects a projected balance above the cap', () => {
      const { engine } = buildEngine();
      const decision = engine.checkWalletBalance(LIMITS.maxOfflineWalletBalancePaise + 1);
      expect(decision.allowed).toBe(false);
      expect(decision.reasonCode).toBe('MAX_WALLET_BALANCE_EXCEEDED');
    });
  });

  describe('checkSinglePayment (FR-RSK-01)', () => {
    it('allows a payment at or below the per-transaction cap', () => {
      const { engine } = buildEngine();
      expect(engine.checkSinglePayment(LIMITS.maxSingleOfflinePaymentPaise).allowed).toBe(true);
    });

    it('rejects a payment above the per-transaction cap', () => {
      const { engine } = buildEngine();
      const decision = engine.checkSinglePayment(LIMITS.maxSingleOfflinePaymentPaise + 1);
      expect(decision.allowed).toBe(false);
      expect(decision.reasonCode).toBe('MAX_SINGLE_PAYMENT_EXCEEDED');
    });
  });

  describe('checkCumulativeSpending (FR-RSK-02)', () => {
    it('allows spending that stays within the cumulative window cap', async () => {
      const { engine, activity } = buildEngine();
      await activity.record('acct-1', 5_000 * 100, FIXED_NOW);
      const decision = await engine.checkCumulativeSpending('acct-1', 4_000 * 100, FIXED_NOW);
      expect(decision.allowed).toBe(true);
    });

    it('rejects spending that would push cumulative total over the cap', async () => {
      const { engine, activity } = buildEngine();
      await activity.record('acct-1', 8_000 * 100, FIXED_NOW);
      const decision = await engine.checkCumulativeSpending('acct-1', 3_000 * 100, FIXED_NOW);
      expect(decision.allowed).toBe(false);
      expect(decision.reasonCode).toBe('MAX_CUMULATIVE_OFFLINE_EXCEEDED');
    });

    it('ignores activity outside the rolling window', async () => {
      const { engine, activity } = buildEngine();
      const longAgo = new Date(FIXED_NOW.getTime() - LIMITS.cumulativeWindowHours * 3_600_000 - 1000);
      await activity.record('acct-1', 9_000 * 100, longAgo);
      const decision = await engine.checkCumulativeSpending('acct-1', 5_000 * 100, FIXED_NOW);
      expect(decision.allowed).toBe(true);
    });
  });

  describe('checkDailyTransactionCount', () => {
    it('allows up to the configured daily count', async () => {
      const { engine, activity } = buildEngine();
      await activity.record('acct-1', 100, FIXED_NOW);
      await activity.record('acct-1', 100, FIXED_NOW);
      // 2 recorded + this one would be #3, at the cap (3) — allowed.
      const decision = await engine.checkDailyTransactionCount('acct-1', FIXED_NOW);
      expect(decision.allowed).toBe(true);
    });

    it('rejects once the daily count would be exceeded', async () => {
      const { engine, activity } = buildEngine();
      await activity.record('acct-1', 100, FIXED_NOW);
      await activity.record('acct-1', 100, FIXED_NOW);
      await activity.record('acct-1', 100, FIXED_NOW);
      const decision = await engine.checkDailyTransactionCount('acct-1', FIXED_NOW);
      expect(decision.allowed).toBe(false);
      expect(decision.reasonCode).toBe('MAX_DAILY_TX_COUNT_EXCEEDED');
    });
  });

  describe('checkVelocity', () => {
    it('rejects a burst of payments within the short velocity window', async () => {
      const { engine, activity } = buildEngine();
      await activity.record('acct-1', 100, FIXED_NOW);
      await activity.record('acct-1', 100, FIXED_NOW);
      const decision = await engine.checkVelocity('acct-1', FIXED_NOW);
      expect(decision.allowed).toBe(false);
      expect(decision.reasonCode).toBe('VELOCITY_LIMIT_EXCEEDED');
    });

    it('allows payments spaced outside the velocity window even if the daily count would allow more', async () => {
      const { engine, activity } = buildEngine();
      const outsideVelocityWindow = new Date(FIXED_NOW.getTime() - (LIMITS.velocityWindowMinutes + 1) * 60_000);
      await activity.record('acct-1', 100, outsideVelocityWindow);
      const decision = await engine.checkVelocity('acct-1', FIXED_NOW);
      expect(decision.allowed).toBe(true);
    });
  });

  describe('evaluateOfflinePayment (combines all rules; raises a RiskFlag on rejection)', () => {
    it('allows a normal payment with no prior activity', async () => {
      const { engine } = buildEngine();
      const decision = await engine.evaluateOfflinePayment('acct-1', 1_000 * 100, FIXED_NOW);
      expect(decision.allowed).toBe(true);
    });

    it('rejects and raises a RiskFlag when the single-payment cap is exceeded', async () => {
      const { engine, flags } = buildEngine();
      const decision = await engine.evaluateOfflinePayment('acct-1', LIMITS.maxSingleOfflinePaymentPaise + 1, FIXED_NOW);
      expect(decision.allowed).toBe(false);
      expect(decision.reasonCode).toBe('MAX_SINGLE_PAYMENT_EXCEEDED');
      expect(flags.all()).toHaveLength(1);
      expect(flags.all()[0]!.subjectId).toBe('acct-1');
      expect(flags.all()[0]!.reasonCode).toBe('MAX_SINGLE_PAYMENT_EXCEEDED');
    });

    it('does not raise a flag when the payment is allowed', async () => {
      const { engine, flags } = buildEngine();
      await engine.evaluateOfflinePayment('acct-1', 1_000 * 100, FIXED_NOW);
      expect(await flags.countAll()).toBe(0);
    });

    it('checks velocity before cumulative (fails fast on the cheaper/shorter-window rule)', async () => {
      const { engine, activity } = buildEngine();
      // Two prior payments -> velocity (max 2) would be exceeded by a third,
      // regardless of cumulative amount (well under the cumulative cap).
      await activity.record('acct-1', 10, FIXED_NOW);
      await activity.record('acct-1', 10, FIXED_NOW);
      const decision = await engine.evaluateOfflinePayment('acct-1', 10, FIXED_NOW);
      expect(decision.allowed).toBe(false);
      expect(decision.reasonCode).toBe('VELOCITY_LIMIT_EXCEEDED');
    });
  });

  describe('recordAcceptedPayment', () => {
    it('makes subsequent evaluations see the recorded activity', async () => {
      const { engine, activity } = buildEngine();
      await engine.recordAcceptedPayment('acct-1', 9_000 * 100, FIXED_NOW);
      expect(await activity.sumSince('acct-1', new Date(FIXED_NOW.getTime() - 1000))).toBe(9_000 * 100);
    });
  });
});
