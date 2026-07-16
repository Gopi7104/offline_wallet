import { Router } from 'express';
import { MerchantRepository } from '../../identity/domain/merchant_repository';
import { LedgerRepository } from '../../ledger/domain/ledger_repository';
import { SpentTokenIndex } from '../domain/spent_token_index';
import { SettlementRepository } from '../domain/settlement_repository';
import { PgSpentTokenIndex } from '../infra/pg_spent_token_index';
import { PgSettlementRepository } from '../infra/pg_settlement_repository';
import { SettlementService } from '../application/settlement_service';
import { SettlementController } from './settlement_controller';
import { getPool } from '../../../platform/db';

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
  },
): void {
  const spentTokenIndex = deps.spentTokenIndex ?? new PgSpentTokenIndex(getPool());
  const settlementRepository = deps.settlementRepository ?? new PgSettlementRepository(getPool());

  const service = new SettlementService(
    deps.merchantRepository,
    spentTokenIndex,
    deps.ledgerRepository,
    settlementRepository,
  );
  const controller = new SettlementController(service);

  router.post('/settlement', (req, res) => controller.settle(req, res));

  // Test helpers (temporary), consistent with the wallet/identity contexts.
  (router as any).__spentTokenIndex = spentTokenIndex;
  (router as any).__settlementRepository = settlementRepository;
}
