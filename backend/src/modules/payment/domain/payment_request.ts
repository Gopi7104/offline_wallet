import { Money } from '../../../shared/money';
import { randomUUID } from 'crypto';

/**
 * PaymentRequest — a customer's intent to pay a merchant (Task 5 placeholder).
 *
 * SCOPE (Architecture v1.1): the real payment path is OFFLINE — the payer signs
 * a Transfer and hands coins to the merchant over BLE with NO server round-trip
 * at pay time (§7, D1). This online request object is a placeholder for the
 * Customer Pay vertical slice: it lets the app validate a merchant + amount
 * against the backend before the offline protocol exists. No coins move, no
 * settlement, no cryptography.
 * TODO(Payment full impl): replace with the signed offline Transfer aggregate
 * (§4.2 `Transfer`, §7). Immutable.
 */
export type PaymentRequestStatus = 'CREATED';

export class PaymentRequest {
  constructor(
    readonly paymentRequestId: string,
    readonly payerAccountId: string,
    readonly merchantId: string,
    readonly merchantName: string,
    readonly amount: Money,
    readonly status: PaymentRequestStatus,
    readonly createdAt: Date,
  ) {}

  static create(
    payerAccountId: string,
    merchantId: string,
    merchantName: string,
    amount: Money,
    now: Date,
  ): PaymentRequest {
    return new PaymentRequest(
      randomUUID(),
      payerAccountId,
      merchantId,
      merchantName,
      amount,
      'CREATED',
      now,
    );
  }
}
