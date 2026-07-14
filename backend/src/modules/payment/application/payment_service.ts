import { Money } from '../../../shared/money';
import { MerchantRepository } from '../../identity/domain/merchant_repository';
import { PaymentRequest } from '../domain/payment_request';

/**
 * PaymentService — Customer Pay use cases (Task 5 placeholder), Payment /
 * Transfer context. Validates that the target merchant exists (looked up via
 * Identity's MerchantRepository port) and builds a placeholder PaymentRequest.
 * No BLE, no token transfer, no settlement, no cryptography (Task 5 scope).
 */
export class PaymentService {
  constructor(
    private readonly merchants: MerchantRepository,
    private readonly clock: () => Date = () => new Date(),
  ) {}

  /**
   * Create a placeholder payment request against a merchant. Amount is
   * validated by the caller (controller) before this runs. Returns null if the
   * merchant does not exist (the caller maps that to 404).
   */
  async createPaymentRequest(
    payerAccountId: string,
    merchantId: string,
    amount: Money,
  ): Promise<PaymentRequest | null> {
    const merchant = await this.merchants.findByMerchantId(merchantId);
    if (!merchant) return null;
    return PaymentRequest.create(
      payerAccountId,
      merchant.merchantId,
      merchant.displayName,
      amount,
      this.clock(),
    );
  }
}
