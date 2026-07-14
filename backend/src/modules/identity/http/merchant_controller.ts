import { Request, Response } from 'express';
import { MerchantService } from '../application/merchant_service';
import { MerchantProfile } from '../domain/merchant_profile';

/**
 * HTTP controller (interface adapter) for Merchant Mode, in the Identity &
 * Device context. Parses requests, calls the service, returns JSON
 * (ARCHITECTURE.md §5.1). Auth is stubbed via the x-account-id header,
 * consistent with WalletController (a later task replaces it with the Firebase
 * session exchange). Public API and response contracts are unchanged from
 * Task 4.
 */
export class MerchantController {
  constructor(private readonly service: MerchantService) {}

  /** POST /v1/merchant/enable — switch the account into Merchant Mode. */
  async enable(req: Request, res: Response): Promise<void> {
    try {
      const accountId = this.extractAccountId(req);
      const displayName =
        typeof req.body?.displayName === 'string' ? req.body.displayName : undefined;
      const profile = await this.service.enableMerchantMode(accountId, displayName);
      res.status(201).json(this.toJson(profile));
    } catch (error) {
      this.handleError(error, res);
    }
  }

  /** GET /v1/merchant — merchant dashboard (Merchant ID + wallet buckets). */
  async getDashboard(req: Request, res: Response): Promise<void> {
    try {
      const accountId = this.extractAccountId(req);
      const profile = await this.service.getByAccountId(accountId);
      if (!profile) {
        res.status(404).json({
          error: 'MERCHANT_NOT_ENABLED',
          message: 'Merchant Mode is not enabled for this account',
        });
        return;
      }
      res.json(this.toJson(profile));
    } catch (error) {
      this.handleError(error, res);
    }
  }

  /** POST /v1/merchant/qr — generate a placeholder payment QR payload. */
  async generateQr(req: Request, res: Response): Promise<void> {
    try {
      const accountId = this.extractAccountId(req);

      let amountPaise: number | undefined;
      if (req.body?.amount !== undefined) {
        const amount = req.body.amount;
        if (typeof amount !== 'number' || !Number.isInteger(amount) || amount < 0) {
          res.status(400).json({
            error: 'INVALID_AMOUNT',
            message: 'amount must be a non-negative integer (paise)',
          });
          return;
        }
        amountPaise = amount;
      }

      const payload = await this.service.generateQrPayload(accountId, amountPaise);
      if (!payload) {
        res.status(404).json({
          error: 'MERCHANT_NOT_ENABLED',
          message: 'Enable Merchant Mode before generating a QR',
        });
        return;
      }
      res.status(201).json(payload);
    } catch (error) {
      this.handleError(error, res);
    }
  }

  private toJson(m: MerchantProfile) {
    return {
      merchantId: m.merchantId,
      accountId: m.accountId,
      displayName: m.displayName,
      wallet: {
        pendingSettlement: {
          paise: m.wallet.pendingSettlement.paise,
          currency: m.wallet.pendingSettlement.currency,
        },
        settled: {
          paise: m.wallet.settled.paise,
          currency: m.wallet.settled.currency,
        },
        total: { paise: m.wallet.total.paise, currency: m.wallet.total.currency },
      },
      createdAt: m.createdAt.toISOString(),
    };
  }

  private extractAccountId(req: Request): string {
    // Stubbed auth: extract from the session/JWT in a later task.
    return (req.headers['x-account-id'] as string) || 'test-account-1';
  }

  private handleError(error: unknown, res: Response): void {
    console.error('MerchantController error:', error);
    res.status(500).json({ error: 'INTERNAL_ERROR', message: 'An error occurred' });
  }
}
