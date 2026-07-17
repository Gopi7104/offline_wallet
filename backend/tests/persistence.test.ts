import { Pool } from 'pg';
import { loadConfig } from '../src/platform/config';
import { getPool } from '../src/platform/db';
import { PgWalletRepository } from '../src/modules/wallet/infra/pg_wallet_repository';
import { PgTokenRepository } from '../src/modules/issuance/infra/pg_token_repository';
import { PgMerchantRepository } from '../src/modules/identity/infra/pg_merchant_repository';
import { PgSettlementRepository } from '../src/modules/settlement/infra/pg_settlement_repository';
import { PgSpentTokenIndex } from '../src/modules/settlement/infra/pg_spent_token_index';
import { PgLedgerRepository } from '../src/modules/ledger/infra/pg_ledger_repository';
import { WalletService } from '../src/modules/wallet/application/wallet_service';
import { IssuanceService } from '../src/modules/issuance/application/issuance_service';
import { MerchantService } from '../src/modules/identity/application/merchant_service';
import { SettlementResult } from '../src/modules/settlement/domain/settlement_result';
import { LedgerEntry } from '../src/modules/ledger/domain/ledger_entry';
import { Wallet } from '../src/modules/wallet/domain/wallet';
import { Token } from '../src/modules/issuance/domain/token';
import { Money } from '../src/shared/money';
import { unwrap } from '../src/shared/result';

/**
 * A brand-new Pool (not the shared test pool from tests/setup/db_setup.ts)
 * stands in for "the backend process restarted": no in-memory state can
 * possibly leak across it, so a read through it only succeeds if the data
 * really made it to PostgreSQL.
 */
function freshPool(): Pool {
  const { databaseUrl } = loadConfig();
  return new Pool({ connectionString: databaseUrl });
}

describe('PostgreSQL persistence — data survives a simulated backend restart', () => {
  it('wallet balance survives a restart', async () => {
    const walletService1 = new WalletService(
      new PgWalletRepository(getPool()),
      new IssuanceService(new PgTokenRepository(getPool())),
    );
    await walletService1.loadWallet('restart-wallet-1', unwrap(Money.fromRupees(37)));

    const pool2 = freshPool();
    try {
      const wallet = await new PgWalletRepository(pool2).findByAccountId('restart-wallet-1');
      expect(wallet?.balance.paise).toBe(3700);
    } finally {
      await pool2.end();
    }
  });

  it('tokens survive a restart', async () => {
    const issuance1 = new IssuanceService(new PgTokenRepository(getPool()));
    const tokens = await issuance1.issueTokens('restart-tokens-1', unwrap(Money.fromRupees(17)));

    const pool2 = freshPool();
    try {
      const found = await new PgTokenRepository(pool2).findByOwner('restart-tokens-1');
      expect(found.map((t) => t.tokenId).sort()).toEqual(tokens.map((t) => t.tokenId).sort());
      expect(found.reduce((sum, t) => sum + t.denomination.paise, 0)).toBe(1700);
    } finally {
      await pool2.end();
    }
  });

  it('merchant profile survives a restart', async () => {
    const merchantService1 = new MerchantService(new PgMerchantRepository(getPool()));
    const profile = await merchantService1.enableMerchantMode('restart-merchant-1', 'Restart Store');

    const pool2 = freshPool();
    try {
      const found = await new PgMerchantRepository(pool2).findByMerchantId(profile.merchantId);
      expect(found?.accountId).toBe('restart-merchant-1');
      expect(found?.displayName).toBe('Restart Store');
    } finally {
      await pool2.end();
    }
  });

  it('settlement records and merchant settled balance survive a restart', async () => {
    const settlementRepo1 = new PgSettlementRepository(getPool());
    const merchantId = 'MER-RESTART00001';
    const result = new SettlementResult(
      'SET-restart-1',
      merchantId,
      ['tok-1', 'tok-2'],
      [],
      [],
      unwrap(Money.fromRupees(7)),
      'LED-restart-1',
      'SUCCESS',
      new Date(),
    );
    await settlementRepo1.creditMerchant(merchantId, result.creditedAmount);
    await settlementRepo1.record(result);

    const pool2 = freshPool();
    try {
      const settlementRepo2 = new PgSettlementRepository(pool2);
      expect((await settlementRepo2.settledBalance(merchantId)).paise).toBe(700);
      const history = await settlementRepo2.historyFor(merchantId);
      expect(history).toHaveLength(1);
      expect(history[0]!.settlementId).toBe('SET-restart-1');
      expect(history[0]!.acceptedTokenIds).toEqual(['tok-1', 'tok-2']);
    } finally {
      await pool2.end();
    }
  });

  it('ledger entries survive a restart, with the hash chain intact', async () => {
    const ledgerRepo1 = new PgLedgerRepository(getPool());
    const prevHash = await ledgerRepo1.headHash();
    const entry = LedgerEntry.forSettlement({
      merchantId: 'MER-RESTART00002',
      amount: unwrap(Money.fromRupees(5)),
      acceptedTokenIds: ['a'],
      rejectedTokenIds: [],
      duplicateTokenIds: [],
      status: 'SUCCESS',
      timestamp: new Date(),
      prevHash,
    });
    await ledgerRepo1.append(entry);

    const pool2 = freshPool();
    try {
      const found = await new PgLedgerRepository(pool2).findById(entry.ledgerId);
      expect(found?.hash).toBe(entry.hash);
      expect(found?.prevHash).toBe(prevHash);
      expect(found?.amount.paise).toBe(500);
      expect(found?.acceptedTokenIds).toEqual(['a']);
    } finally {
      await pool2.end();
    }
  });

  it('appendAtomically serializes concurrent appends — no fork under a real race', async () => {
    const ledgerRepo = new PgLedgerRepository(getPool());
    const before = await ledgerRepo.all();

    const buildEntry = (tag: string) => (prevHash: string | null) =>
      LedgerEntry.forSettlement({
        merchantId: `MER-RACE-${tag}`,
        amount: unwrap(Money.fromRupees(1)),
        acceptedTokenIds: [`race-${tag}`],
        rejectedTokenIds: [],
        duplicateTokenIds: [],
        status: 'SUCCESS',
        timestamp: new Date(),
        prevHash,
      });

    // Fire concurrent appends through the same atomic path the settlement
    // service uses — this is exactly what would fork the chain (two entries
    // both pointing at the same prevHash) without the advisory lock in
    // appendAtomically().
    const N = 8;
    await Promise.all(Array.from({ length: N }, (_, i) => ledgerRepo.appendAtomically(buildEntry(`${i}`))));

    const all = await ledgerRepo.all();
    const appended = all.slice(before.length);
    expect(appended).toHaveLength(N);

    // The chain must be a single, unforked sequence: each entry's prevHash
    // equals the immediately preceding entry's hash, in seq order.
    let expectedPrev = before[before.length - 1]?.hash ?? null;
    for (const entry of appended) {
      expect(entry.prevHash).toBe(expectedPrev);
      expectedPrev = entry.hash;
    }
  });

  it('duplicate spent-token detection persists across a restart', async () => {
    const firstClaim = await new PgSpentTokenIndex(getPool()).tryClaim('restart-spent-token-1');
    expect(firstClaim).toBe(true);

    const pool2 = freshPool();
    try {
      const spentIndex2 = new PgSpentTokenIndex(pool2);
      expect(await spentIndex2.tryClaim('restart-spent-token-1')).toBe(false);
      expect(await spentIndex2.isSpent('restart-spent-token-1')).toBe(true);
    } finally {
      await pool2.end();
    }
  });
});

describe('Double-spend detection under real concurrency (DB unique constraint)', () => {
  it('only one of two concurrent claims of the same token wins', async () => {
    const index = new PgSpentTokenIndex(getPool());
    const [a, b] = await Promise.all([
      index.tryClaim('concurrent-spend-token-1'),
      index.tryClaim('concurrent-spend-token-1'),
    ]);
    expect([a, b].filter(Boolean)).toHaveLength(1);
  });
});

describe('Transactions rollback correctly', () => {
  it('PgWalletRepository.save rolls back the delete+insert together on a constraint violation', async () => {
    const walletRepo = new PgWalletRepository(getPool());

    const goodToken = Token.create(unwrap(Money.fromRupees(10)), 'rollback-wallet-1', new Date()).withStatus(
      'in_wallet',
    );
    await walletRepo.save(new Wallet('rollback-wallet-1', [goodToken]));

    const before = await walletRepo.findByAccountId('rollback-wallet-1');
    expect(before?.tokens.map((t) => t.tokenId)).toEqual([goodToken.tokenId]);

    // A token with a zero denomination is a valid Money value but violates
    // wallet_tokens' `denomination_paise > 0` CHECK constraint — this forces
    // the INSERT half of save()'s DELETE-then-INSERT transaction to fail.
    const badToken = new Token(
      'bad-token-zero-denom',
      Money.zero(),
      'rollback-wallet-1',
      new Date(),
      new Date(Date.now() + 86_400_000),
      'in_wallet',
      'sig',
    );
    await expect(walletRepo.save(new Wallet('rollback-wallet-1', [badToken]))).rejects.toThrow();

    // Rolled back: the DELETE never committed either, so the prior snapshot
    // (the good token) is still there — not empty, and not the bad token.
    const after = await walletRepo.findByAccountId('rollback-wallet-1');
    expect(after?.tokens.map((t) => t.tokenId)).toEqual([goodToken.tokenId]);
  });
});
