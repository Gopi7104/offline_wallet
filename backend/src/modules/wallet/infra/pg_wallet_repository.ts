import { Pool } from 'pg';
import { withTransaction } from '../../../platform/db';
import { unwrap } from '../../../shared/result';
import { Money } from '../../../shared/money';
import { Token, TokenStatus } from '../../issuance/domain/token';
import { Wallet } from '../domain/wallet';
import { WalletRepository } from '../domain/wallet_repository';

interface WalletTokenRow {
  token_id: string;
  denomination_paise: string;
  owner_id: string;
  issued_at: Date;
  expiry: Date;
  status: TokenStatus;
  bank_signature: string;
}

function toToken(row: WalletTokenRow): Token {
  return new Token(
    row.token_id,
    unwrap(Money.fromPaise(Number(row.denomination_paise))),
    row.owner_id,
    row.issued_at,
    row.expiry,
    row.status,
    row.bank_signature,
  );
}

/**
 * PgWalletRepository — PostgreSQL adapter for the Wallet (server shadow)
 * context (ARCHITECTURE.md §5.2 `wallet_shadows`, migration 003). Replaces
 * InMemoryWalletRepository; same port, same "full replace" save semantics as
 * the in-memory Map (wallet/domain/wallet.ts holds the whole token list, so
 * `save` mirrors that snapshot exactly).
 */
export class PgWalletRepository implements WalletRepository {
  constructor(private readonly pool: Pool) {}

  async findByAccountId(accountId: string): Promise<Wallet | null> {
    const walletRes = await this.pool.query('SELECT account_id FROM wallets WHERE account_id = $1', [accountId]);
    if (walletRes.rows.length === 0) return null;

    const { rows } = await this.pool.query<WalletTokenRow>(
      'SELECT * FROM wallet_tokens WHERE account_id = $1',
      [accountId],
    );
    return new Wallet(accountId, rows.map(toToken));
  }

  /**
   * Replace the account's full token snapshot in one transaction: upsert the
   * wallet row, delete its previous tokens, insert the current set. Delete +
   * insert must be atomic — a failure partway (e.g. a constraint violation)
   * rolls back to the prior snapshot rather than leaving the wallet empty.
   */
  async save(wallet: Wallet): Promise<void> {
    await withTransaction(async (client) => {
      await client.query(
        `INSERT INTO wallets (account_id) VALUES ($1)
         ON CONFLICT (account_id) DO UPDATE SET updated_at = now()`,
        [wallet.accountId],
      );
      await client.query('DELETE FROM wallet_tokens WHERE account_id = $1', [wallet.accountId]);

      if (wallet.tokens.length === 0) return;

      const columns = [
        'token_id',
        'account_id',
        'denomination_paise',
        'owner_id',
        'issued_at',
        'expiry',
        'status',
        'bank_signature',
      ];
      const values: unknown[] = [];
      const rowPlaceholders = wallet.tokens.map((token, i) => {
        const base = i * columns.length;
        values.push(
          token.tokenId,
          wallet.accountId,
          token.denomination.paise,
          token.ownerId,
          token.issuedAt,
          token.expiry,
          token.status,
          token.bankSignature,
        );
        return `(${columns.map((_, j) => `$${base + j + 1}`).join(', ')})`;
      });

      await client.query(
        `INSERT INTO wallet_tokens (${columns.join(', ')}) VALUES ${rowPlaceholders.join(', ')}`,
        values,
      );
    });
  }
}
