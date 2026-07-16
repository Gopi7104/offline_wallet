import { Router, Request, Response } from 'express';
import { LedgerRepository } from '../domain/ledger_repository';
import { LedgerEntry } from '../domain/ledger_entry';

/**
 * Ledger context (ARCHITECTURE.md §4.1, §5.4).
 * Owns: immutable, hash-chained event log; money-supply invariant
 * (FR-LED-01/02/03). Never mutated; source of truth for value.
 *
 * Task 9 exposes GET /v1/ledger — read-only projection of the append-only log
 * (settlement entries) — so the ledger can be inspected/audited. The shared
 * LedgerRepository is injected by the composition root; the Settlement context
 * appends to the same instance.
 */
export function registerLedgerRoutes(
  router: Router,
  deps: { ledgerRepository: LedgerRepository },
): void {
  router.get('/ledger', async (_req: Request, res: Response) => {
    const entries = await deps.ledgerRepository.all();
    res.status(200).json({ entries: entries.map(toJson) });
  });

  router.get('/ledger/:ledgerId', async (req: Request, res: Response) => {
    const ledgerId = req.params.ledgerId;
    if (!ledgerId) {
      res.status(404).json({ error: 'LEDGER_ENTRY_NOT_FOUND' });
      return;
    }
    const entry = await deps.ledgerRepository.findById(ledgerId);
    if (!entry) {
      res.status(404).json({ error: 'LEDGER_ENTRY_NOT_FOUND' });
      return;
    }
    res.status(200).json(toJson(entry));
  });
}

function toJson(e: LedgerEntry) {
  return {
    ledgerId: e.ledgerId,
    eventType: e.eventType,
    merchantId: e.merchantId,
    amount: { paise: e.amount.paise, currency: e.amount.currency },
    acceptedTokenIds: e.acceptedTokenIds,
    rejectedTokenIds: e.rejectedTokenIds,
    duplicateTokenIds: e.duplicateTokenIds,
    status: e.status,
    timestamp: e.timestamp.toISOString(),
    prevHash: e.prevHash,
    hash: e.hash,
  };
}
