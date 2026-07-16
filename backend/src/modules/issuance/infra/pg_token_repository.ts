import { Pool } from 'pg';
import { unwrap } from '../../../shared/result';
import { Money } from '../../../shared/money';
import { Token, TokenStatus } from '../domain/token';
import { TokenRepository } from '../domain/token_repository';

interface TokenRow {
  token_id: string;
  denomination_paise: string;
  owner_id: string;
  issued_at: Date;
  expiry: Date;
  status: TokenStatus;
  bank_signature: string;
}

function toDomain(row: TokenRow): Token {
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
 * PgTokenRepository — PostgreSQL adapter for the Issuance (Mint) context
 * (ARCHITECTURE.md §5.2 `coins`/`tokens`, migration 002). Replaces
 * InMemoryTokenRepository; same port, same semantics.
 */
export class PgTokenRepository implements TokenRepository {
  constructor(private readonly pool: Pool) {}

  async save(token: Token): Promise<void> {
    await this.saveMany([token]);
  }

  async saveMany(tokens: Token[]): Promise<void> {
    if (tokens.length === 0) return;

    // Single multi-row INSERT: all tokens from one mint land atomically
    // (ARCHITECTURE.md §5.3 "atomic value movements"), not one-by-one.
    const columns = ['token_id', 'denomination_paise', 'owner_id', 'issued_at', 'expiry', 'status', 'bank_signature'];
    const values: unknown[] = [];
    const rows: string[] = tokens.map((token, i) => {
      const base = i * columns.length;
      values.push(
        token.tokenId,
        token.denomination.paise,
        token.ownerId,
        token.issuedAt,
        token.expiry,
        token.status,
        token.bankSignature,
      );
      return `(${columns.map((_, j) => `$${base + j + 1}`).join(', ')})`;
    });

    await this.pool.query(
      `INSERT INTO tokens (${columns.join(', ')})
       VALUES ${rows.join(', ')}
       ON CONFLICT (token_id) DO UPDATE SET
         denomination_paise = EXCLUDED.denomination_paise,
         owner_id = EXCLUDED.owner_id,
         issued_at = EXCLUDED.issued_at,
         expiry = EXCLUDED.expiry,
         status = EXCLUDED.status,
         bank_signature = EXCLUDED.bank_signature`,
      values,
    );
  }

  async findById(tokenId: string): Promise<Token | null> {
    const { rows } = await this.pool.query<TokenRow>('SELECT * FROM tokens WHERE token_id = $1', [tokenId]);
    return rows[0] ? toDomain(rows[0]) : null;
  }

  async findByOwner(ownerId: string): Promise<Token[]> {
    const { rows } = await this.pool.query<TokenRow>('SELECT * FROM tokens WHERE owner_id = $1', [ownerId]);
    return rows.map(toDomain);
  }
}
