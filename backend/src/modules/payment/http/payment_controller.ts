import { Request, Response } from 'express';
import { Money } from '../../../shared/money';
import { isErr, unwrap } from '../../../shared/result';
import { PaymentService } from '../application/payment_service';
import { PaymentRequest } from '../domain/payment_request';

/**
 * HTTP controller (interface adapter) for the Customer Pay flow, Payment /
 * Transfer context. The payer's account identity comes from `req.accountId`,
 * resolved by `resolveAccountId` (Firebase ID token, FR-ID-01). Placeholder
 * only — see PaymentRequest.
 */
export class PaymentController {
  constructor(private readonly service: PaymentService) {}

  /** POST /v1/payment/request — validate merchant + amount, return a request. */
  async createRequest(req: Request, res: Response): Promise<void> {
    try {
      const payerAccountId = this.extractAccountId(req);
      const { merchantId, amount } = req.body ?? {};

      if (typeof merchantId !== 'string' || merchantId.trim() === '') {
        res.status(400).json({
          error: 'INVALID_MERCHANT_ID',
          message: 'merchantId is required',
        });
        return;
      }

      if (typeof amount !== 'number' || !Number.isInteger(amount) || amount <= 0) {
        res.status(400).json({
          error: 'INVALID_AMOUNT',
          message: 'amount must be a positive integer (paise)',
        });
        return;
      }

      const amountR = Money.fromPaise(amount);
      if (isErr(amountR)) {
        res.status(400).json({ error: 'INVALID_AMOUNT', message: amountR.error.message });
        return;
      }

      const request = await this.service.createPaymentRequest(
        payerAccountId,
        merchantId,
        unwrap(amountR),
      );
      if (!request) {
        res.status(404).json({
          error: 'MERCHANT_NOT_FOUND',
          message: 'No merchant exists for the given merchantId',
        });
        return;
      }

      res.status(201).json(this.toJson(request));
    } catch (error) {
      this.handleError(error, res);
    }
  }

  private toJson(r: PaymentRequest) {
    return {
      paymentRequestId: r.paymentRequestId,
      payerAccountId: r.payerAccountId,
      merchantId: r.merchantId,
      merchantName: r.merchantName,
      amount: { paise: r.amount.paise, currency: r.amount.currency },
      status: r.status,
      createdAt: r.createdAt.toISOString(),
    };
  }

  private extractAccountId(req: Request): string {
    // Set by resolveAccountId (auth_middleware.ts) ahead of every /v1 route.
    return req.accountId ?? 'test-account-1';
  }

  private handleError(error: unknown, res: Response): void {
    console.error('PaymentController error:', error);
    res.status(500).json({ error: 'INTERNAL_ERROR', message: 'An error occurred' });
  }
}
