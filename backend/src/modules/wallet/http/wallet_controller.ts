import { Request, Response } from 'express';
import { Money } from '../../../shared/money';
import { isErr, unwrap } from '../../../shared/result';
import { WalletService, HoldingCapExceeded } from '../application/wallet_service';

/**
 * HTTP controller (interface adapter). Parses requests, calls the service,
 * returns JSON responses (ARCHITECTURE.md §5.1 "Interface / Adapters").
 * Error handling is basic here; in production, a middleware would catch
 * and format domain errors.
 */
export class WalletController {
  constructor(private readonly service: WalletService) {}

  /**
   * GET /v1/wallet — fetch current balance.
   * Auth: session required — account identity resolved from the Firebase
   * ID token by resolveAccountId (FR-ID-01).
   */
  async getWallet(req: Request, res: Response): Promise<void> {
    try {
      const accountId = this.extractAccountId(req);
      const balance = await this.service.getBalance(accountId);
      if (!balance) {
        // Wallet doesn't exist yet; return zero balance.
        const zero = unwrap(Money.fromPaise(0));
        res.json({ accountId, balance: { paise: zero.paise, currency: zero.currency } });
        return;
      }
      res.json({
        accountId,
        balance: { paise: balance.paise, currency: balance.currency },
      });
    } catch (error) {
      this.handleError(error, res);
    }
  }

  /**
   * POST /v1/wallet/load — load funds into the wallet from the bank.
   * Body: { amount: number (paise) }
   * Returns: new balance.
   * In a real system, this would be atomic: bank debit + mint + ledger (FR-ISS-02).
   */
  async loadWallet(req: Request, res: Response): Promise<void> {
    try {
      const accountId = this.extractAccountId(req);
      const { amount: amountPaise } = req.body ?? {};

      // Consistent with the payment endpoint: reject non-numbers, non-integers,
      // and non-positive amounts (0 and negatives) with one INVALID_AMOUNT shape.
      if (typeof amountPaise !== 'number' || !Number.isInteger(amountPaise) || amountPaise <= 0) {
        res
          .status(400)
          .json({ error: 'INVALID_AMOUNT', message: 'amount must be a positive integer (paise)' });
        return;
      }

      const amountR = Money.fromPaise(amountPaise);
      if (isErr(amountR)) {
        res.status(400).json({ error: 'INVALID_AMOUNT', message: 'amount must be a positive integer (paise)' });
        return;
      }
      const amount = unwrap(amountR);

      const newBalance = await this.service.loadWallet(accountId, amount);
      res.status(201).json({
        accountId,
        loaded: { paise: amount.paise, currency: amount.currency },
        newBalance: { paise: newBalance.paise, currency: newBalance.currency },
      });
    } catch (error) {
      // FR-ISS-06 holding cap → 400 JSON (a well-formed but rejected request).
      if (error instanceof HoldingCapExceeded) {
        res.status(400).json({ error: error.code, message: error.message });
        return;
      }
      this.handleError(error, res);
    }
  }

  private extractAccountId(req: Request): string {
    // Set by resolveAccountId (auth_middleware.ts) ahead of every /v1 route.
    return req.accountId ?? 'test-account-1';
  }

  private handleError(error: unknown, res: Response): void {
    console.error('WalletController error:', error);
    res.status(500).json({ error: 'INTERNAL_ERROR', message: 'An error occurred' });
  }
}
