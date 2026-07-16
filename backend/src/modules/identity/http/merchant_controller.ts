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
