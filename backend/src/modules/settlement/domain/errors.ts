import { DomainError } from '../../../shared/errors';

/**
 * Settlement-level failures — request-shaped problems that stop a settlement
 * before any per-token processing. Per-token outcomes (expired, duplicate) are
 * NOT errors; they are counted in the SettlementResult. (ARCHITECTURE.md §11:
 * expected failures are typed and returned via Result.)
 */

/** No tokens were submitted. Maps to HTTP 400. */
export class EmptySettlement extends DomainError {
  readonly code = 'EMPTY_SETTLEMENT';
  constructor() {
    super('Settlement contained no tokens');
  }
}

/** The payload was structurally invalid (bad token entry, missing field). 400. */
export class MalformedSettlement extends DomainError {
  readonly code = 'MALFORMED_PAYLOAD';
  constructor(detail = 'Settlement payload is malformed') {
    super(detail);
  }
}

/** The target merchant is not registered. Maps to HTTP 404. */
export class UnknownMerchant extends DomainError {
  readonly code = 'UNKNOWN_MERCHANT';
  constructor(merchantId: string) {
    super(`No merchant exists for merchantId '${merchantId}'`);
  }
}

export type SettlementError = EmptySettlement | MalformedSettlement | UnknownMerchant;
