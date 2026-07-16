import request from 'supertest';
import { createServer } from '../src/platform/httpServer';
import { InMemoryMerchantRepository } from '../src/modules/identity/infra/in_memory_merchant_repository';
import { MerchantService } from '../src/modules/identity/application/merchant_service';
import { InMemoryLedgerRepository } from '../src/modules/ledger/infra/in_memory_ledger_repository';
import { InMemorySpentTokenIndex } from '../src/modules/settlement/infra/in_memory_spent_token_index';
import { InMemorySettlementRepository } from '../src/modules/settlement/infra/in_memory_settlement_repository';
import { SettlementService } from '../src/modules/settlement/application/settlement_service';
import { SubmittedToken } from '../src/modules/settlement/domain/submitted_token';

/**
 * Task 9 — Settlement & Double-Spend Detection.
 * Covers the eight backend acceptance cases: successful settlement, duplicate
 * detection, already-redeemed, unknown merchant, malformed payload, ledger
 * append, merchant-credited-once, and repeat-settlement rejection.
 */

const FIXED_NOW = new Date('2026-07-16T10:00:00.000Z');

/** A token in the mobile wire shape ({id, denom, owner, iat, exp, status, sig}). */
function wireToken(
  id: string,
  denomPaise: number,
  opts: { expiredBy?: number } = {},
): Record<string, unknown> {
  const iat = Math.floor(FIXED_NOW.getTime() / 1000) - 3600;
  const exp = opts.expiredBy
    ? Math.floor(FIXED_NOW.getTime() / 1000) - opts.expiredBy
    : Math.floor(FIXED_NOW.getTime() / 1000) + 86400; // +1 day by default
  return {
    id,
    denom: denomPaise,
    owner: 'payer-1',
    iat,
    exp,
    status: 'inTransit',
    sig: 'issuer-sig-placeholder',
  };
}

function parse(...raw: Record<string, unknown>[]): SubmittedToken[] {
  return raw.map((r) => {
    const t = SubmittedToken.fromWire(r);
    if (!t) throw new Error('test token was malformed');
    return t;
  });
}

describe('Settlement service (application/domain, Task 9)', () => {
  let merchants: InMemoryMerchantRepository;
  let merchantService: MerchantService;
  let ledger: InMemoryLedgerRepository;
  let spent: InMemorySpentTokenIndex;
  let settlements: InMemorySettlementRepository;
  let service: SettlementService;
  let merchantId: string;

  beforeEach(async () => {
    merchants = new InMemoryMerchantRepository();
    merchantService = new MerchantService(merchants);
    ledger = new InMemoryLedgerRepository();
    spent = new InMemorySpentTokenIndex();
    settlements = new InMemorySettlementRepository();
    service = new SettlementService(merchants, spent, ledger, settlements, () => FIXED_NOW);
    const merchant = await merchantService.enableMerchantMode('acct-1', 'Corner Shop');
    merchantId = merchant.merchantId;
  });

  it('settles valid tokens: accepts all, credits the exact sum, appends a ledger entry', async () => {
    const tokens = parse(wireToken('t1', 50000), wireToken('t2', 20000), wireToken('t3', 5000));
    const out = await service.settle({ merchantId, tokens });

    expect(out.ok).toBe(true);
    if (!out.ok) return;
    expect(out.value.acceptedCount).toBe(3);
    expect(out.value.rejectedCount).toBe(0);
    expect(out.value.duplicateCount).toBe(0);
    expect(out.value.creditedAmount.paise).toBe(75000);
    expect(out.value.status).toBe('SUCCESS');
    expect(out.value.ledgerId).toMatch(/^LED-/);

    // Ledger append (immutable log has exactly one entry).
    const entries = await ledger.all();
    expect(entries).toHaveLength(1);
    expect(entries[0]!.ledgerId).toBe(out.value.ledgerId);
    expect(entries[0]!.amount.paise).toBe(75000);
    expect(entries[0]!.acceptedTokenIds).toEqual(['t1', 't2', 't3']);
    expect(entries[0]!.prevHash).toBeNull();
    expect(entries[0]!.hash).toHaveLength(64);

    // Merchant credited once with the accepted sum.
    expect((await settlements.settledBalance(merchantId)).paise).toBe(75000);
  });

  it('detects a double-spend within a single payload (same token id twice)', async () => {
    const tokens = parse(wireToken('dup', 10000), wireToken('dup', 10000));
    const out = await service.settle({ merchantId, tokens });
    expect(out.ok).toBe(true);
    if (!out.ok) return;
    expect(out.value.acceptedCount).toBe(1);
    expect(out.value.duplicateCount).toBe(1);
    expect(out.value.creditedAmount.paise).toBe(10000);
    expect(out.value.status).toBe('PARTIAL');
  });

  it('rejects an already-redeemed token on a later settlement (TOKEN_ALREADY_SPENT)', async () => {
    await service.settle({ merchantId, tokens: parse(wireToken('t1', 50000)) });
    const second = await service.settle({ merchantId, tokens: parse(wireToken('t1', 50000)) });
    expect(second.ok).toBe(true);
    if (!second.ok) return;
    expect(second.value.acceptedCount).toBe(0);
    expect(second.value.duplicateCount).toBe(1);
    expect(second.value.duplicateTokenIds).toEqual(['t1']);
    expect(second.value.status).toBe('REJECTED');
  });

  it('credits the merchant exactly once across a repeat settlement', async () => {
    const tokens = parse(wireToken('t1', 50000), wireToken('t2', 20000));
    await service.settle({ merchantId, tokens });
    expect((await settlements.settledBalance(merchantId)).paise).toBe(70000);

    // Repeat the SAME tokens — all duplicates, nothing credited.
    const repeat = await service.settle({ merchantId, tokens: parse(wireToken('t1', 50000), wireToken('t2', 20000)) });
    expect(repeat.ok).toBe(true);
    if (!repeat.ok) return;
    expect(repeat.value.acceptedCount).toBe(0);
    expect(repeat.value.creditedAmount.paise).toBe(0);
    expect(repeat.value.status).toBe('REJECTED');
    // Balance unchanged: credited once.
    expect((await settlements.settledBalance(merchantId)).paise).toBe(70000);
  });

  it('rejects expired tokens without claiming them in the spent index', async () => {
    const out = await service.settle({
      merchantId,
      tokens: parse(wireToken('fresh', 10000), wireToken('stale', 20000, { expiredBy: 3600 })),
    });
    expect(out.ok).toBe(true);
    if (!out.ok) return;
    expect(out.value.acceptedCount).toBe(1);
    expect(out.value.rejectedCount).toBe(1);
    expect(out.value.rejectedTokenIds).toEqual(['stale']);
    expect(out.value.creditedAmount.paise).toBe(10000);
    // The expired token was never claimed, so it is not marked spent.
    expect(await spent.isSpent('stale')).toBe(false);
  });

  it('returns UnknownMerchant for a merchant that is not registered', async () => {
    const out = await service.settle({ merchantId: 'MER-000000000000', tokens: parse(wireToken('t1', 10000)) });
    expect(out.ok).toBe(false);
    if (out.ok) return;
    expect(out.error.code).toBe('UNKNOWN_MERCHANT');
    // No ledger entry written for a failed settlement.
    expect(await ledger.all()).toHaveLength(0);
  });

  it('returns EmptySettlement when no tokens are submitted', async () => {
    const out = await service.settle({ merchantId, tokens: [] });
    expect(out.ok).toBe(false);
    if (out.ok) return;
    expect(out.error.code).toBe('EMPTY_SETTLEMENT');
  });

  it('hash-chains successive ledger entries (tamper evidence)', async () => {
    await service.settle({ merchantId, tokens: parse(wireToken('a', 10000)) });
    await service.settle({ merchantId, tokens: parse(wireToken('b', 10000)) });
    const entries = await ledger.all();
    expect(entries).toHaveLength(2);
    expect(entries[0]!.prevHash).toBeNull();
    expect(entries[1]!.prevHash).toBe(entries[0]!.hash);
  });
});

describe('Settlement HTTP (POST /v1/settlement, Task 9)', () => {
  const app = createServer();

  async function enableMerchant(accountId: string): Promise<string> {
    const res = await request(app).post('/v1/merchant/enable').set('x-account-id', accountId);
    return res.body.merchantId as string;
  }

  it('200: successful settlement returns counts, credited amount and a ledger id', async () => {
    const merchantId = await enableMerchant('http-mer-1');
    const res = await request(app)
      .post('/v1/settlement')
      .send({ merchantId, tokens: [wireToken('h1', 50000), wireToken('h2', 5000)] });

    expect(res.status).toBe(200);
    expect(res.body.accepted).toBe(2);
    expect(res.body.rejected).toBe(0);
    expect(res.body.duplicates).toBe(0);
    expect(res.body.creditedAmount.paise).toBe(55000);
    expect(res.body.status).toBe('SUCCESS');
    expect(res.body.ledgerId).toMatch(/^LED-/);

    // The appended entry is visible via the read-only ledger endpoint.
    const ledgerRes = await request(app).get(`/v1/ledger/${res.body.ledgerId}`);
    expect(ledgerRes.status).toBe(200);
    expect(ledgerRes.body.amount.paise).toBe(55000);
  });

  it('200: a repeat settlement of the same tokens is rejected (no double-credit)', async () => {
    const merchantId = await enableMerchant('http-mer-2');
    const tokens = [wireToken('r1', 20000)];
    const first = await request(app).post('/v1/settlement').send({ merchantId, tokens });
    expect(first.body.accepted).toBe(1);

    const second = await request(app).post('/v1/settlement').send({ merchantId, tokens });
    expect(second.status).toBe(200);
    expect(second.body.accepted).toBe(0);
    expect(second.body.duplicates).toBe(1);
    expect(second.body.creditedAmount.paise).toBe(0);
    expect(second.body.status).toBe('REJECTED');
  });

  it('404 UNKNOWN_MERCHANT for a merchant that does not exist', async () => {
    const res = await request(app)
      .post('/v1/settlement')
      .send({ merchantId: 'MER-FFFFFFFFFFFF', tokens: [wireToken('x', 10000)] });
    expect(res.status).toBe(404);
    expect(res.body.error).toBe('UNKNOWN_MERCHANT');
  });

  it('400 EMPTY_SETTLEMENT for an empty token list', async () => {
    const merchantId = await enableMerchant('http-mer-3');
    const res = await request(app).post('/v1/settlement').send({ merchantId, tokens: [] });
    expect(res.status).toBe(400);
    expect(res.body.error).toBe('EMPTY_SETTLEMENT');
  });

  it('400 MALFORMED_PAYLOAD for a token missing required fields', async () => {
    const merchantId = await enableMerchant('http-mer-4');
    const res = await request(app)
      .post('/v1/settlement')
      .send({ merchantId, tokens: [{ id: 'bad', denom: 'not-a-number' }] });
    expect(res.status).toBe(400);
    expect(res.body.error).toBe('MALFORMED_PAYLOAD');
  });

  it('400 MALFORMED_PAYLOAD when merchantId is missing', async () => {
    const res = await request(app)
      .post('/v1/settlement')
      .send({ tokens: [wireToken('x', 10000)] });
    expect(res.status).toBe(400);
    expect(res.body.error).toBe('MALFORMED_PAYLOAD');
  });
});
