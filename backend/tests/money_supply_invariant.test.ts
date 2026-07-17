import { getPool } from '../src/platform/db';
import { PgTokenRepository } from '../src/modules/issuance/infra/pg_token_repository';
import { PgMerchantRepository } from '../src/modules/identity/infra/pg_merchant_repository';
import { PgSpentTokenIndex } from '../src/modules/settlement/infra/pg_spent_token_index';
import { PgSettlementRepository } from '../src/modules/settlement/infra/pg_settlement_repository';
import { PgLedgerRepository } from '../src/modules/ledger/infra/pg_ledger_repository';
import { IssuanceService } from '../src/modules/issuance/application/issuance_service';
import { MerchantService } from '../src/modules/identity/application/merchant_service';
import { SettlementService } from '../src/modules/settlement/application/settlement_service';
import { SubmittedToken } from '../src/modules/settlement/domain/submitted_token';
import { Token } from '../src/modules/issuance/domain/token';
import { Money } from '../src/shared/money';
import { unwrap } from '../src/shared/result';

/**
 * Money-supply invariant (CLAUDE.md "Property Tests (Essential)", FR-LED-03):
 * `issued = outstanding + redeemed + expired + written_off` — after ANY
 * workload, value is neither created nor destroyed.
 *
 * This codebase does not yet implement a separate expiry-sweep / write-off
 * ledger bucket (that's future Phase 5/6 work — see docs/TODO.md); expired
 * and forged-and-rejected tokens fold into `outstanding` here (they were
 * issued, never successfully redeemed, and remain fully accounted for — no
 * value vanished). `redeemed` is `settled` (the sum of every `creditedAmount`
 * SettlementService actually returned).
 *
 * Runs against real PostgreSQL (integration test, mirrors persistence.test.ts)
 * so the invariant is checked through the real atomic double-spend claim
 * (the `spent_coins`-equivalent UNIQUE index), not an in-memory stand-in.
 */
function wireOf(token: Token): Record<string, unknown> {
  return {
    id: token.tokenId,
    denom: token.denomination.paise,
    owner: token.ownerId,
    iat: Math.floor(token.issuedAt.getTime() / 1000),
    exp: Math.floor(token.expiry.getTime() / 1000),
    status: token.status,
    sig: token.bankSignature,
  };
}

function parse(...raw: Record<string, unknown>[]): SubmittedToken[] {
  return raw.map((r) => {
    const t = SubmittedToken.fromWire(r);
    if (!t) throw new Error('test token was malformed');
    return t;
  });
}

describe('Money-supply invariant (issued = redeemed + outstanding, across a mixed workload)', () => {
  it('holds after issuance, partial settlement, a double-spend attempt, an expired token, and a forged token', async () => {
    const pool = getPool();
    const tokenRepo = new PgTokenRepository(pool);
    const merchants = new PgMerchantRepository(pool);
    const spent = new PgSpentTokenIndex(pool);
    const settlements = new PgSettlementRepository(pool);
    const ledger = new PgLedgerRepository(pool);

    // 1. Issue: mint a real batch of signed tokens for a payer. Uses a fixed
    // "old" clock so this batch is already expired by the time we settle.
    const mintClock = () => new Date('2026-01-01T00:00:00.000Z');
    const issuance = new IssuanceService(tokenRepo, undefined, mintClock);
    const ownerId = 'invariant-payer-1';
    const issued = await issuance.issueTokens(ownerId, unwrap(Money.fromRupees(237))); // ₹200+20+10+5+2
    const issuedPaise = issued.reduce((sum, t) => sum + t.denomination.paise, 0);
    expect(issuedPaise).toBe(23700);

    // Also mint a small FRESH (non-expired) batch to actually settle.
    const freshClock = () => new Date('2026-07-16T00:00:00.000Z');
    const freshIssuance = new IssuanceService(tokenRepo, undefined, freshClock);
    const freshIssued = await freshIssuance.issueTokens(ownerId, unwrap(Money.fromRupees(50))); // ₹50
    const totalIssuedPaise = issuedPaise + freshIssued.reduce((s, t) => s + t.denomination.paise, 0);

    const merchant = await new MerchantService(merchants).enableMerchantMode(
      'invariant-merchant-acct',
      'Invariant Test Store',
    );
    // Settlement runs "now" well past the old batch's 30-day expiry.
    const settleClock = () => new Date('2026-07-17T00:00:00.000Z');
    const service = new SettlementService(merchants, spent, ledger, settlements, settleClock);

    let creditedPaise = 0;
    const acceptedTokenIds = new Set<string>();

    // 2. Settle only the FRESH batch (the old batch is expired and would be
    // rejected) — leaves the old batch entirely "outstanding" for now.
    const firstBatch = await service.settle({ merchantId: merchant.merchantId, tokens: parse(...freshIssued.map(wireOf)) });
    expect(firstBatch.ok).toBe(true);
    if (firstBatch.ok) {
      creditedPaise += firstBatch.value.creditedAmount.paise;
      firstBatch.value.acceptedTokenIds.forEach((id) => acceptedTokenIds.add(id));
    }

    // 3. Double-spend attempt: resubmit the SAME already-settled tokens.
    // Must not credit anything additional (first-valid-wins, D3).
    const replay = await service.settle({ merchantId: merchant.merchantId, tokens: parse(...freshIssued.map(wireOf)) });
    expect(replay.ok).toBe(true);
    if (replay.ok) {
      expect(replay.value.acceptedCount).toBe(0);
      creditedPaise += replay.value.creditedAmount.paise; // must add 0
    }

    // 4. Submit the OLD (now-expired) batch — rejected for expiry, never
    // credited, never claimed in the spent index; still fully "outstanding".
    const expiredBatch = await service.settle({ merchantId: merchant.merchantId, tokens: parse(...issued.map(wireOf)) });
    expect(expiredBatch.ok).toBe(true);
    if (expiredBatch.ok) {
      expect(expiredBatch.value.acceptedCount).toBe(0);
      expect(expiredBatch.value.rejectedCount).toBe(issued.length);
      creditedPaise += expiredBatch.value.creditedAmount.paise; // must add 0
    }

    // 5. A forged token (no real issued token behind it at all — an
    // attacker-fabricated wire entry with a garbage signature). Rejected on
    // signature verification, contributes to neither issued nor credited.
    const forged = await service.settle({
      merchantId: merchant.merchantId,
      tokens: parse({
        id: 'forged-token-1',
        denom: 10000,
        owner: ownerId,
        iat: Math.floor(freshClock().getTime() / 1000),
        exp: Math.floor(freshClock().getTime() / 1000) + 86400,
        status: 'inTransit',
        sig: 'ab'.repeat(64), // well-formed hex, not a real signature
      }),
    });
    expect(forged.ok).toBe(true);
    if (forged.ok) {
      expect(forged.value.acceptedCount).toBe(0);
      creditedPaise += forged.value.creditedAmount.paise; // must add 0
    }

    // --- Independently derive each bucket and check the invariant ---

    // `redeemed`/settled: sum of denominations of every token id this test's
    // OWN records show was accepted (cross-referenced against the real
    // issued tokens, not trusted from the service's own credited total).
    const allIssued = [...issued, ...freshIssued];
    const acceptedSumPaise = allIssued
      .filter((t) => acceptedTokenIds.has(t.tokenId))
      .reduce((sum, t) => sum + t.denomination.paise, 0);

    // The service's reported credited total must match that independent sum
    // — proving the double-spend/expired/forged rejections truly added zero.
    expect(creditedPaise).toBe(acceptedSumPaise);

    // `outstanding`: every genuinely-issued token NOT among the accepted ids
    // (never-submitted + rejected-for-expiry here — no separate expiry/
    // write-off bucket exists yet; see file header).
    const outstandingPaise = allIssued
      .filter((t) => !acceptedTokenIds.has(t.tokenId))
      .reduce((sum, t) => sum + t.denomination.paise, 0);

    // The headline invariant: nothing created, nothing destroyed.
    expect(totalIssuedPaise).toBe(creditedPaise + outstandingPaise);

    // Sanity: the fresh batch (₹50) was fully redeemed; the old batch (₹237)
    // is fully outstanding (expired, unredeemed).
    expect(creditedPaise).toBe(5000);
    expect(outstandingPaise).toBe(23700);
  });
});
