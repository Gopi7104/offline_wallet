import { Request, Response } from 'express';
import { SettlementService, SettlementCommand } from '../application/settlement_service';
import { SubmittedToken } from '../domain/submitted_token';
import { SettlementResult } from '../domain/settlement_result';
import {
  EmptySettlement,
  MalformedSettlement,
  UnknownMerchant,
} from '../domain/errors';

/**
 * HTTP controller (interface adapter) for Settlement, POST /v1/settlement.
 * Parses + structurally validates the wire payload, delegates to the service,
 * and maps typed domain errors to HTTP status codes:
 *   400 EMPTY_SETTLEMENT / MALFORMED_PAYLOAD, 404 UNKNOWN_MERCHANT.
 * Token-level outcomes (expired / already-spent) come back inside the 200 body.
 */
export class SettlementController {
  constructor(private readonly service: SettlementService) {}

  /** POST /v1/settlement */
  async settle(req: Request, res: Response): Promise<void> {
    try {
      const body = req.body as unknown;
      if (typeof body !== 'object' || body === null) {
        res.status(400).json({ error: 'MALFORMED_PAYLOAD', message: 'Request body must be an object' });
        return;
      }
      const { merchantId, tokens } = body as Record<string, unknown>;

      if (typeof merchantId !== 'string' || merchantId.trim() === '') {
        res.status(400).json({
          error: 'MALFORMED_PAYLOAD',
          message: 'merchantId is required',
        });
        return;
      }
      if (!Array.isArray(tokens)) {
        res.status(400).json({
          error: 'MALFORMED_PAYLOAD',
          message: 'tokens must be an array',
        });
        return;
      }
      if (tokens.length === 0) {
        res.status(400).json({
          error: 'EMPTY_SETTLEMENT',
          message: 'Settlement contained no tokens',
        });
        return;
      }

      // Parse every token up-front; a single malformed entry fails the whole
      // payload (400) — distinct from a valid-but-rejected (expired/duplicate)
      // token, which is reported in the 200 body.
      const parsed: SubmittedToken[] = [];
      for (const raw of tokens) {
        const token = SubmittedToken.fromWire(raw);
        if (token === null) {
          res.status(400).json({
            error: 'MALFORMED_PAYLOAD',
            message: 'One or more tokens are malformed',
          });
          return;
        }
        parsed.push(token);
      }

      const command: SettlementCommand = { merchantId, tokens: parsed };
      const outcome = await this.service.settle(command);

      if (!outcome.ok) {
        this.handleDomainError(outcome.error, res);
        return;
      }

      res.status(200).json(this.toJson(outcome.value));
    } catch (error) {
      console.error('SettlementController error:', error);
      res.status(500).json({ error: 'INTERNAL_ERROR', message: 'An error occurred' });
    }
  }

  private handleDomainError(error: Error, res: Response): void {
    if (error instanceof UnknownMerchant) {
      res.status(404).json({ error: error.code, message: error.message });
      return;
    }
    if (error instanceof EmptySettlement || error instanceof MalformedSettlement) {
      res.status(400).json({ error: error.code, message: error.message });
      return;
    }
    res.status(500).json({ error: 'INTERNAL_ERROR', message: 'An error occurred' });
  }

  /** Wire response (§5.6). Counts + credited amount + ledger id + status. */
  private toJson(r: SettlementResult) {
    return {
      settlementId: r.settlementId,
      merchantId: r.merchantId,
      accepted: r.acceptedCount,
      rejected: r.rejectedCount,
      duplicates: r.duplicateCount,
      acceptedTokenIds: r.acceptedTokenIds,
      rejectedTokenIds: r.rejectedTokenIds,
      duplicateTokenIds: r.duplicateTokenIds,
      creditedAmount: { paise: r.creditedAmount.paise, currency: r.creditedAmount.currency },
      ledgerId: r.ledgerId,
      status: r.status,
      settledAt: r.settledAt.toISOString(),
    };
  }
}
