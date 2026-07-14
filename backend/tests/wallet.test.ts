import request from 'supertest';
import { createServer } from '../src/platform/httpServer';
import { Wallet, TokenNotFoundError } from '../src/modules/wallet/domain/wallet';
import { InMemoryWalletRepository } from '../src/modules/wallet/infra/in_memory_wallet_repository';
import { InMemoryTokenRepository } from '../src/modules/issuance/infra/in_memory_token_repository';
import { WalletService, HoldingCapExceeded } from '../src/modules/wallet/application/wallet_service';
import { IssuanceService } from '../src/modules/issuance/application/issuance_service';
import { Token, IllegalTokenTransition } from '../src/modules/issuance/domain/token';
import { Money, PAISE_PER_RUPEE } from '../src/shared/money';
import { unwrap } from '../src/shared/result';

describe('Wallet (Task 3: digital cash tokens)', () => {
  describe('Token aggregate (domain)', () => {
    it('creates a token with unique ID', () => {
      const denom = unwrap(Money.fromRupees(10));
      const token = Token.create(denom, 'alice', new Date());
      expect(token.tokenId).toBeTruthy();
      expect(token.denomination.paise).toBe(1000);
      expect(token.ownerId).toBe('alice');
      expect(token.status).toBe('minted');
    });

    it('tokens are immutable: withStatus returns new token', () => {
      const denom = unwrap(Money.fromRupees(5));
      const token1 = Token.create(denom, 'bob', new Date());
      const token2 = token1.withStatus('in_wallet');
      expect(token1.status).toBe('minted');
      expect(token2.status).toBe('in_wallet');
      expect(token1.tokenId).toBe(token2.tokenId); // same token
    });

    it('rejects illegal lifecycle transitions', () => {
      const denom = unwrap(Money.fromRupees(5));
      const minted = Token.create(denom, 'bob', new Date());
      // minted -> in_transit skips in_wallet: illegal.
      expect(() => minted.withStatus('in_transit')).toThrow(IllegalTokenTransition);
      // minted -> redeemed skips in_wallet and in_transit: illegal.
      expect(() => minted.withStatus('redeemed')).toThrow(IllegalTokenTransition);

      const redeemed = minted.withStatus('in_wallet').withStatus('in_transit').withStatus('redeemed');
      // redeemed is terminal: no further transitions allowed.
      expect(() => redeemed.withStatus('in_wallet')).toThrow(IllegalTokenTransition);
    });

    it('tracks expiry', () => {
      const denom = unwrap(Money.fromRupees(1));
      const now = new Date();
      const token = Token.create(denom, 'charlie', now, 30);
      expect(token.isExpired(now)).toBe(false);
      const later = new Date(now);
      later.setDate(later.getDate() + 31);
      expect(token.isExpired(later)).toBe(true);
    });
  });

  describe('Wallet aggregate (domain) — token-based', () => {
    it('starts with empty token list', () => {
      const w = Wallet.empty('alice');
      expect(w.accountId).toBe('alice');
      expect(w.tokens).toEqual([]);
      expect(w.balance.paise).toBe(0);
    });

    it('computes balance from token denominations', () => {
      const t1 = Token.create(unwrap(Money.fromRupees(10)), 'bob', new Date());
      const t2 = Token.create(unwrap(Money.fromRupees(5)), 'bob', new Date());
      const w = Wallet.empty('bob').addTokens([t1, t2]);
      expect(w.balance.paise).toBe(1500); // ₹15
    });

    it('addTokens is immutable', () => {
      const w1 = Wallet.empty('charlie');
      const token = Token.create(unwrap(Money.fromRupees(20)), 'charlie', new Date());
      const w2 = w1.addTokens([token]);
      expect(w1.tokens).toHaveLength(0);
      expect(w2.tokens).toHaveLength(1);
    });

    it('addTokens transitions tokens minted -> in_wallet', () => {
      const token = Token.create(unwrap(Money.fromRupees(20)), 'charlie', new Date());
      expect(token.status).toBe('minted');
      const w = Wallet.empty('charlie').addTokens([token]);
      expect(w.tokens[0]!.status).toBe('in_wallet');
    });

    it('addTokens rejects a token that is not currently minted', () => {
      const token = Token.create(unwrap(Money.fromRupees(20)), 'charlie', new Date());
      const w = Wallet.empty('charlie').addTokens([token]);
      const alreadyInWallet = w.tokens[0]!;
      expect(() => Wallet.empty('charlie').addTokens([alreadyInWallet])).toThrow(IllegalTokenTransition);
    });

    it('markTokensAsTransferred updates status', () => {
      const t1 = Token.create(unwrap(Money.fromRupees(5)), 'dave', new Date());
      const t2 = Token.create(unwrap(Money.fromRupees(10)), 'dave', new Date());
      let w = Wallet.empty('dave').addTokens([t1, t2]);
      w = w.markTokensAsTransferred([t1.tokenId]);
      expect(w.tokens).toHaveLength(2);
      expect(w.tokens[0]!.status).toBe('in_transit');
      expect(w.tokens[1]!.status).toBe('in_wallet');
    });

    it('markTokensAsTransferred throws TokenNotFoundError for an unknown token ID', () => {
      const t1 = Token.create(unwrap(Money.fromRupees(5)), 'dave', new Date());
      const w = Wallet.empty('dave').addTokens([t1]);
      expect(() => w.markTokensAsTransferred(['does-not-exist'])).toThrow(TokenNotFoundError);
    });

    it('markTokensAsTransferred throws when a token is not currently in_wallet', () => {
      const t1 = Token.create(unwrap(Money.fromRupees(5)), 'dave', new Date());
      let w = Wallet.empty('dave').addTokens([t1]);
      w = w.markTokensAsTransferred([t1.tokenId]); // now in_transit
      expect(() => w.markTokensAsTransferred([t1.tokenId])).toThrow(IllegalTokenTransition);
    });
  });

  describe('IssuanceService (application)', () => {
    let tokenRepo: InMemoryTokenRepository;
    let service: IssuanceService;

    beforeEach(() => {
      tokenRepo = new InMemoryTokenRepository();
      service = new IssuanceService(tokenRepo);
    });

    it('creates tokens with fine denominations', async () => {
      const amount = unwrap(Money.fromRupees(17)); // ₹17 should split greedy
      const tokens = await service.issueTokens('eve', amount);
      // ₹17 = ₹10 + ₹5 + ₹2
      expect(tokens).toHaveLength(3);
      expect(tokens[0]!.denomination.paise).toBe(1000); // ₹10
      expect(tokens[1]!.denomination.paise).toBe(500); // ₹5
      expect(tokens[2]!.denomination.paise).toBe(200); // ₹2
    });

    it('sums to the requested amount', async () => {
      const amount = unwrap(Money.fromRupees(123));
      const tokens = await service.issueTokens('frank', amount);
      const total = tokens.reduce((sum, t) => sum.add(t.denomination), Money.zero());
      expect(total.paise).toBe(amount.paise);
    });
  });

  describe('WalletService (application)', () => {
    let walletRepo: InMemoryWalletRepository;
    let tokenRepo: InMemoryTokenRepository;
    let service: WalletService;

    beforeEach(() => {
      walletRepo = new InMemoryWalletRepository();
      tokenRepo = new InMemoryTokenRepository();
      const issuanceService = new IssuanceService(tokenRepo);
      service = new WalletService(walletRepo, issuanceService);
    });

    it('returns null for unknown account', async () => {
      const balance = await service.getBalance('unknown');
      expect(balance).toBeNull();
    });

    it('loads wallet with tokens and returns new balance', async () => {
      const amount = unwrap(Money.fromRupees(50));
      const newBalance = await service.loadWallet('grace', amount);
      expect(newBalance.paise).toBe(5000);
    });

    it('accumulates loads (tokens are added)', async () => {
      const twenty = unwrap(Money.fromRupees(20));
      await service.loadWallet('henry', twenty);
      const newBalance = await service.loadWallet('henry', twenty);
      expect(newBalance.paise).toBe(4000); // ₹40
    });

    it('getBalance reflects tokens', async () => {
      const amount = unwrap(Money.fromRupees(33));
      await service.loadWallet('ivy', amount);
      const balance = await service.getBalance('ivy');
      expect(balance?.paise).toBe(3300);
    });

    it('rejects a load that would exceed the holding cap (FR-ISS-06)', async () => {
      const overCap = unwrap(Money.fromPaise(WalletService.DEFAULT_MAX_HOLDING_PAISE + 100));
      await expect(service.loadWallet('cap-user', overCap)).rejects.toBeInstanceOf(HoldingCapExceeded);
      // Over-cap request must not mint anything.
      expect(await service.getBalance('cap-user')).toBeNull();
    });

    it('allows a load exactly at the holding cap', async () => {
      const atCap = unwrap(Money.fromPaise(WalletService.DEFAULT_MAX_HOLDING_PAISE));
      const balance = await service.loadWallet('cap-edge', atCap);
      expect(balance.paise).toBe(WalletService.DEFAULT_MAX_HOLDING_PAISE);
    });
  });

  describe('HTTP integration (Task 3: tokens internal, API external same as Task 2)', () => {
    const app = createServer();

    it('GET /v1/wallet returns balance (tokens hidden)', async () => {
      const res = await request(app).get('/v1/wallet').set('x-account-id', 'jack');
      expect(res.status).toBe(200);
      expect(res.body.accountId).toBe('jack');
      expect(res.body.balance.paise).toBe(0);
      // Tokens are internal; API does not expose them
      expect(res.body.tokens).toBeUndefined();
    });

    it('POST /v1/wallet/load creates tokens, returns balance', async () => {
      const loadRes = await request(app)
        .post('/v1/wallet/load')
        .set('x-account-id', 'kate')
        .send({ amount: 15 * PAISE_PER_RUPEE }); // ₹15

      expect(loadRes.status).toBe(201);
      expect(loadRes.body.accountId).toBe('kate');
      expect(loadRes.body.loaded.paise).toBe(1500);
      expect(loadRes.body.newBalance.paise).toBe(1500);
      // Tokens are internal
      expect(loadRes.body.tokens).toBeUndefined();
    });

    it('accumulates loads (tokens accumulate)', async () => {
      const amount = 50 * PAISE_PER_RUPEE;
      await request(app)
        .post('/v1/wallet/load')
        .set('x-account-id', 'leo')
        .send({ amount });
      const res2 = await request(app)
        .post('/v1/wallet/load')
        .set('x-account-id', 'leo')
        .send({ amount });
      expect(res2.body.newBalance.paise).toBe(2 * amount);
    });

    it('rejects invalid amount', async () => {
      const res = await request(app)
        .post('/v1/wallet/load')
        .set('x-account-id', 'mara')
        .send({ amount: 1.5 });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('INVALID_AMOUNT');
    });

    it('GET /v1/wallet reflects all loads (balance is sum of tokens)', async () => {
      const accountId = 'nancy';
      await request(app)
        .post('/v1/wallet/load')
        .set('x-account-id', accountId)
        .send({ amount: 7 * PAISE_PER_RUPEE });
      const res = await request(app).get('/v1/wallet').set('x-account-id', accountId);
      expect(res.body.balance.paise).toBe(700);
    });

    it('rejects loading amount 0 (INVALID_AMOUNT, consistent with payment)', async () => {
      const res = await request(app)
        .post('/v1/wallet/load')
        .set('x-account-id', 'zero-acct')
        .send({ amount: 0 });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('INVALID_AMOUNT');
    });

    it('rejects a load above the holding cap with JSON (FR-ISS-06)', async () => {
      const res = await request(app)
        .post('/v1/wallet/load')
        .set('x-account-id', 'cap-http')
        .send({ amount: 50_000 * PAISE_PER_RUPEE + 100 });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('HOLDING_CAP_EXCEEDED');
    });

    it('returns a JSON error (not HTML) for malformed JSON', async () => {
      const res = await request(app)
        .post('/v1/wallet/load')
        .set('x-account-id', 'json-acct')
        .set('Content-Type', 'application/json')
        .send('{ bad json');
      expect(res.status).toBe(400);
      expect(res.body.error).toBe('INVALID_JSON');
    });
  });
});
