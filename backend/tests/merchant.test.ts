import request from 'supertest';
import { createServer } from '../src/platform/httpServer';
import { Merchant, MerchantWallet, generateMerchantId } from '../src/modules/merchant/domain/merchant';
import { InMemoryMerchantRepository } from '../src/modules/merchant/infra/in_memory_merchant_repository';
import { MerchantService } from '../src/modules/merchant/application/merchant_service';

describe('Merchant Mode (Task 4: vertical slice)', () => {
  describe('Merchant aggregate (domain)', () => {
    it('creates a merchant with a generated ID and an empty wallet', () => {
      const now = new Date();
      const m = Merchant.create('alice', 'Alice Store', now);
      expect(m.accountId).toBe('alice');
      expect(m.displayName).toBe('Alice Store');
      expect(m.merchantId).toMatch(/^MER-[0-9A-F]{12}$/);
      expect(m.wallet.pendingSettlement.paise).toBe(0);
      expect(m.wallet.settled.paise).toBe(0);
      expect(m.createdAt).toBe(now);
    });

    it('MerchantWallet.total sums pending + settled', () => {
      const w = MerchantWallet.empty();
      expect(w.total.paise).toBe(0);
    });
  });

  describe('Merchant ID generation', () => {
    it('is well-formed (MER- + 12 uppercase hex)', () => {
      expect(generateMerchantId()).toMatch(/^MER-[0-9A-F]{12}$/);
    });

    it('is unique across many generations', () => {
      const ids = new Set<string>();
      for (let i = 0; i < 1000; i++) {
        ids.add(generateMerchantId());
      }
      expect(ids.size).toBe(1000);
    });
  });

  describe('MerchantService (application)', () => {
    let repo: InMemoryMerchantRepository;
    let service: MerchantService;

    beforeEach(() => {
      repo = new InMemoryMerchantRepository();
      service = new MerchantService(repo);
    });

    it('enables merchant mode and persists the merchant', async () => {
      const m = await service.enableMerchantMode('bob');
      expect(m.accountId).toBe('bob');
      const found = await repo.findByAccountId('bob');
      expect(found?.merchantId).toBe(m.merchantId);
    });

    it('is idempotent: re-enabling keeps the same Merchant ID', async () => {
      const first = await service.enableMerchantMode('carol');
      const second = await service.enableMerchantMode('carol');
      expect(second.merchantId).toBe(first.merchantId);
    });

    it('getByAccountId returns null when not enabled', async () => {
      expect(await service.getByAccountId('nobody')).toBeNull();
    });

    it('generateQrPayload returns null when not enabled', async () => {
      expect(await service.generateQrPayload('nobody')).toBeNull();
    });

    it('generateQrPayload returns a placeholder payload bound to the merchant', async () => {
      const m = await service.enableMerchantMode('dave');
      const payload = await service.generateQrPayload('dave');
      expect(payload).not.toBeNull();
      expect(payload!.v).toBe(1);
      expect(payload!.merchantId).toBe(m.merchantId);
      expect(payload!.nonce).toBeTruthy();
      expect(typeof payload!.ts).toBe('string');
      expect(payload!.amountPaise).toBeUndefined();
    });

    it('generateQrPayload includes the requested amount when provided', async () => {
      await service.enableMerchantMode('erin');
      const payload = await service.generateQrPayload('erin', 20000);
      expect(payload!.amountPaise).toBe(20000);
    });

    it('generates a fresh nonce per QR', async () => {
      await service.enableMerchantMode('frank');
      const a = await service.generateQrPayload('frank');
      const b = await service.generateQrPayload('frank');
      expect(a!.nonce).not.toBe(b!.nonce);
    });
  });

  describe('HTTP integration (Merchant Mode API)', () => {
    const app = createServer();

    it('POST /v1/merchant/enable returns 201 with a Merchant ID and empty wallet', async () => {
      const res = await request(app).post('/v1/merchant/enable').set('x-account-id', 'grace');
      expect(res.status).toBe(201);
      expect(res.body.accountId).toBe('grace');
      expect(res.body.merchantId).toMatch(/^MER-[0-9A-F]{12}$/);
      expect(res.body.wallet.pendingSettlement.paise).toBe(0);
      expect(res.body.wallet.settled.paise).toBe(0);
      expect(res.body.wallet.total.paise).toBe(0);
    });

    it('POST /v1/merchant/enable is idempotent for the same account', async () => {
      const first = await request(app).post('/v1/merchant/enable').set('x-account-id', 'heidi');
      const second = await request(app).post('/v1/merchant/enable').set('x-account-id', 'heidi');
      expect(second.body.merchantId).toBe(first.body.merchantId);
    });

    it('GET /v1/merchant returns 404 before Merchant Mode is enabled', async () => {
      const res = await request(app).get('/v1/merchant').set('x-account-id', 'ivan');
      expect(res.status).toBe(404);
      expect(res.body.error).toBe('MERCHANT_NOT_ENABLED');
    });

    it('GET /v1/merchant returns the dashboard once enabled', async () => {
      await request(app).post('/v1/merchant/enable').set('x-account-id', 'judy');
      const res = await request(app).get('/v1/merchant').set('x-account-id', 'judy');
      expect(res.status).toBe(200);
      expect(res.body.merchantId).toMatch(/^MER-[0-9A-F]{12}$/);
    });

    it('POST /v1/merchant/qr returns a placeholder payload once enabled', async () => {
      const enable = await request(app).post('/v1/merchant/enable').set('x-account-id', 'ken');
      const res = await request(app)
        .post('/v1/merchant/qr')
        .set('x-account-id', 'ken')
        .send({ amount: 50000 });
      expect(res.status).toBe(201);
      expect(res.body.merchantId).toBe(enable.body.merchantId);
      expect(res.body.nonce).toBeTruthy();
      expect(res.body.amountPaise).toBe(50000);
    });

    it('POST /v1/merchant/qr returns 404 before Merchant Mode is enabled', async () => {
      const res = await request(app).post('/v1/merchant/qr').set('x-account-id', 'laura');
      expect(res.status).toBe(404);
      expect(res.body.error).toBe('MERCHANT_NOT_ENABLED');
    });

    it('POST /v1/merchant/qr rejects a non-integer amount', async () => {
      await request(app).post('/v1/merchant/enable').set('x-account-id', 'mike');
      const res = await request(app)
        .post('/v1/merchant/qr')
        .set('x-account-id', 'mike')
        .send({ amount: 1.5 });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('INVALID_AMOUNT');
    });
  });
});
