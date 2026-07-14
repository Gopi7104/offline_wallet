import request from 'supertest';
import { createServer } from '../src/platform/httpServer';
import { Money } from '../src/shared/money';
import { unwrap } from '../src/shared/result';
import { PaymentRequest } from '../src/modules/payment/domain/payment_request';
import { PaymentService } from '../src/modules/payment/application/payment_service';
import { InMemoryMerchantRepository } from '../src/modules/identity/infra/in_memory_merchant_repository';
import { MerchantService } from '../src/modules/identity/application/merchant_service';

describe('Customer Pay (Task 5: vertical slice; Payment context, placeholder)', () => {
  describe('PaymentRequest aggregate (domain)', () => {
    it('creates a CREATED request with a generated id', () => {
      const now = new Date();
      const amount = unwrap(Money.fromRupees(25));
      const pr = PaymentRequest.create('payer-1', 'MER-ABC123DEF456', 'Alice Store', amount, now);
      expect(pr.paymentRequestId).toBeTruthy();
      expect(pr.payerAccountId).toBe('payer-1');
      expect(pr.merchantId).toBe('MER-ABC123DEF456');
      expect(pr.merchantName).toBe('Alice Store');
      expect(pr.amount.paise).toBe(2500);
      expect(pr.status).toBe('CREATED');
      expect(pr.createdAt).toBe(now);
    });
  });

  describe('PaymentService (application)', () => {
    let merchants: InMemoryMerchantRepository;
    let merchantService: MerchantService;
    let payments: PaymentService;

    beforeEach(() => {
      merchants = new InMemoryMerchantRepository();
      merchantService = new MerchantService(merchants);
      payments = new PaymentService(merchants);
    });

    it('returns null when the merchant does not exist', async () => {
      const amount = unwrap(Money.fromRupees(10));
      expect(await payments.createPaymentRequest('payer', 'MER-000000000000', amount)).toBeNull();
    });

    it('creates a request bound to an existing merchant', async () => {
      const merchant = await merchantService.enableMerchantMode('shopkeeper', 'Corner Shop');
      const amount = unwrap(Money.fromRupees(30));
      const pr = await payments.createPaymentRequest('payer', merchant.merchantId, amount);
      expect(pr).not.toBeNull();
      expect(pr!.merchantId).toBe(merchant.merchantId);
      expect(pr!.merchantName).toBe('Corner Shop');
      expect(pr!.amount.paise).toBe(3000);
    });
  });

  describe('HTTP integration (Customer Pay API)', () => {
    const app = createServer();

    // Enable a merchant via the Identity route, then pay it via the Payment
    // route — this also proves the shared merchant store wiring (Task 5).
    async function enableMerchant(accountId: string): Promise<string> {
      const res = await request(app).post('/v1/merchant/enable').set('x-account-id', accountId);
      return res.body.merchantId as string;
    }

    it('POST /v1/payment/request returns 201 for a valid merchant + amount', async () => {
      const merchantId = await enableMerchant('mer-a');
      const res = await request(app)
        .post('/v1/payment/request')
        .set('x-account-id', 'cust-a')
        .send({ merchantId, amount: 2500 });
      expect(res.status).toBe(201);
      expect(res.body.paymentRequestId).toBeTruthy();
      expect(res.body.payerAccountId).toBe('cust-a');
      expect(res.body.merchantId).toBe(merchantId);
      expect(res.body.amount.paise).toBe(2500);
      expect(res.body.status).toBe('CREATED');
    });

    it('returns 404 MERCHANT_NOT_FOUND for an unknown merchant', async () => {
      const res = await request(app)
        .post('/v1/payment/request')
        .set('x-account-id', 'cust-b')
        .send({ merchantId: 'MER-FFFFFFFFFFFF', amount: 1000 });
      expect(res.status).toBe(404);
      expect(res.body.error).toBe('MERCHANT_NOT_FOUND');
    });

    it('returns 400 INVALID_AMOUNT for a non-positive or non-integer amount', async () => {
      const merchantId = await enableMerchant('mer-c');
      for (const amount of [0, -100, 1.5]) {
        const res = await request(app)
          .post('/v1/payment/request')
          .set('x-account-id', 'cust-c')
          .send({ merchantId, amount });
        expect(res.status).toBe(400);
        expect(res.body.error).toBe('INVALID_AMOUNT');
      }
    });

    it('returns 400 INVALID_MERCHANT_ID when merchantId is missing', async () => {
      const res = await request(app)
        .post('/v1/payment/request')
        .set('x-account-id', 'cust-d')
        .send({ amount: 1000 });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('INVALID_MERCHANT_ID');
    });
  });
});
