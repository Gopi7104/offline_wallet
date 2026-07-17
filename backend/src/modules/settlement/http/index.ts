import { Router } from 'express';
import { MerchantRepository } from '../../identity/domain/merchant_repository';
import { LedgerRepository } from '../../ledger/domain/ledger_repository';
import { SpentTokenIndex } from '../domain/spent_token_index';
import { SettlementRepository } from '../domain/settlement_repository';
import { PgSpentTokenIndex } from '../infra/pg_spent_token_index';
import { PgSettlementRepository } from '../infra/pg_settlement_repository';
import { SettlementService } from '../application/settlement_service';
import { SettlementController } from './settlement_controller';
import { RiskEngine } from '../../risk/application/risk_engine';
import { PgPayerActivityRepository } from '../../risk/infra/pg_payer_activity_repository';
import { PgRiskFlagRepository } from '../../risk/infra/pg_risk_flag_repository';
import { getPool } from '../../../platform/db';
import { loadConfig } from '../../../platform/config';

/**
 * Settlement (Redemption) context (ARCHITECTURE.md §4.1, §5.6, §9).
 * Owns: exactly-once redemption via the spent-token index (double-spend
 * detection, FR-SET-03/05), merchant credit, and one immutable ledger entry
 * per settlement. Endpoint: POST /v1/settlement (Task 9).
 *
 * The spent-token index and settlement repository are created here; the
 * composition root injects the shared merchant + ledger repositories so
 * settlement validates against the same merchant store and appends to the
 * same log.
 */
export function registerSettlementRoutes(
  router: Router,
  deps: {
    merchantRepository: MerchantRepository;
    ledgerRepository: LedgerRepository;
    spentTokenIndex?: SpentTokenIndex;
    settlementRepository?: SettlementRepository;
    riskEngine?: RiskEngine;
  },
): void {
  const spentTokenIndex = deps.spentTokenIndex ?? new PgSpentTokenIndex(getPool());
  const settlementRepository = deps.settlementRepository ?? new PgSettlementRepository(getPool());
  // Per-transaction/cumulative/daily-count/velocity limits (production
  // hardening §2) — sourced from centralized config, decided by Risk.
  const riskEngine =
    deps.riskEngine ??
    new RiskEngine(loadConfig().risk, new PgPayerActivityRepository(getPool()), new PgRiskFlagRepository(getPool()));

  const service = new SettlementService(
    deps.merchantRepository,
    spentTokenIndex,
    deps.ledgerRepository,
    settlementRepository,
    undefined,
    undefined,
    riskEngine,
  );
  const controller = new SettlementController(service);

  router.post('/settlement', (req, res) => controller.settle(req, res));

  // Test helpers (temporary), consistent with the wallet/identity contexts.
  (router as any).__spentTokenIndex = spentTokenIndex;
  (router as any).__settlementRepository = settlementRepository;
}
