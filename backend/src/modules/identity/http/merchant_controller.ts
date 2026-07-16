import { Request, Response } from 'express';
import { MerchantService } from '../application/merchant_service';
import { MerchantProfile } from '../domain/merchant_profile';

/**
 * HTTP controller (interface adapter) for Merchant Mode, in the Identity &
 * Device context. Parses requests, calls the service, returns JSON
 * (ARCHITECTURE.md §5.1). Account identity comes from `req.accountId`,
 * resolved by `resolveAccountId` (Firebase ID token, FR-ID-01). Public API
 * and response contracts are unchanged from Task 4.
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

  /**
   * POST /v1/merchant/qr — create a Payment Request and generate its QR
   * payload (Task 6.7; PAYMENT_PROTOCOL.md §5). `amountPaise` is optional:
   * present → Fixed Amount Payment Request (QR carries `amt`, the payer never
   * enters an amount); omitted → Open Amount Payment Request (QR has no
   * `amt`, the payer enters the amount after scanning). QR/nonce generation
   * itself stays owned by the Payment context (`buildQrPayload`); this
   * endpoint only validates the request and looks up the merchant.
   */
  async generateQr(req: Request, res: Response): Promise<void> {
    try {
      const accountId = this.extractAccountId(req);

      let amountPaise: number | undefined;
      if (req.body?.amountPaise !== undefined) {
        const amount = req.body.amountPaise;
        if (typeof amount !== 'number' || !Number.isInteger(amount) || amount <= 0) {
          res.status(400).json({
            error: 'INVALID_AMOUNT',
            message: 'amountPaise must be a positive integer (paise)',
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
    // Set by resolveAccountId (auth_middleware.ts) ahead of every /v1 route.
    return req.accountId ?? 'test-account-1';
  }

  private handleError(error: unknown, res: Response): void {
    console.error('MerchantController error:', error);
    res.status(500).json({ error: 'INTERNAL_ERROR', message: 'An error occurred' });
  }
}
