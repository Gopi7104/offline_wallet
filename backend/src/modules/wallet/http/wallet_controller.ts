import { Request, Response } from 'express';
import { Money } from '../../../shared/money';
import { isErr, unwrap } from '../../../shared/result';
import { WalletService } from '../application/wallet_service';

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
   * Auth: session required (stubbed here; Task 3 adds Firebase exchange).
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
      const { amount: amountPaise } = req.body;

      if (typeof amountPaise !== 'number') {
        res.status(400).json({ error: 'INVALID_AMOUNT', message: 'amount must be a number' });
        return;
      }

      const amountR = Money.fromPaise(amountPaise);
      if (isErr(amountR)) {
        const err = amountR.error;
        const msg = err instanceof Error ? err.message : String(err);
        res.status(400).json({ error: 'INVALID_AMOUNT', message: msg });
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
      this.handleError(error, res);
    }
  }

  private extractAccountId(req: Request): string {
    // Stubbed: in Task 3, this extracts from the session/JWT.
    // For now, use a header or a test account.
    return (req.headers['x-account-id'] as string) || 'test-account-1';
  }

  private handleError(error: unknown, res: Response): void {
    console.error('WalletController error:', error);
    res.status(500).json({ error: 'INTERNAL_ERROR', message: 'An error occurred' });
  }
}
