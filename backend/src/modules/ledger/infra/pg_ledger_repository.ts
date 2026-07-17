import { Pool, PoolClient } from 'pg';
import { withTransaction } from '../../../platform/db';
import { unwrap } from '../../../shared/result';
import { Money } from '../../../shared/money';
import { LedgerEntry, SettlementLedgerStatus } from '../domain/ledger_entry';
import { LedgerRepository } from '../domain/ledger_repository';

// Arbitrary, fixed key for a Postgres advisory lock scoped to ledger appends
// (pg_advisory_xact_lock takes any bigint — this one has no meaning beyond
// being unique to this purpose). Held only for the duration of the
// transaction in appendAtomically(), so concurrent appends queue up instead
// of racing to read the same head hash.
const LEDGER_APPEND_LOCK_KEY = 0x4c45_4447; // 'LEDG' as hex, arbitrary but stable

interface LedgerEntryRow {
  ledger_id: string;
  event_type: string;
  merchant_id: string;
  amount_paise: string;
  accepted_token_ids: string[];
  rejected_token_ids: string[];
  duplicate_token_ids: string[];
  status: SettlementLedgerStatus;
  entry_timestamp: Date;
  prev_hash: string | null;
  hash: string;
}

// Shared by both a bare pool query (append/headHash) and a transaction client
// (appendAtomically) — Pool and PoolClient expose the same `.query` shape.
type Queryable = Pick<Pool | PoolClient, 'query'>;

async function readHeadHash(db: Queryable): Promise<string | null> {
  const { rows } = await db.query<{ hash: string }>('SELECT hash FROM ledger_entries ORDER BY seq DESC LIMIT 1');
  return rows[0]?.hash ?? null;
}

async function insertEntry(db: Queryable, entry: LedgerEntry): Promise<void> {
  await db.query(
    `INSERT INTO ledger_entries
       (ledger_id, event_type, merchant_id, amount_paise, accepted_token_ids,
        rejected_token_ids, duplicate_token_ids, status, entry_timestamp, prev_hash, hash)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
    [
      entry.ledgerId,
      entry.eventType,
      entry.merchantId,
      entry.amount.paise,
      JSON.stringify(entry.acceptedTokenIds),
      JSON.stringify(entry.rejectedTokenIds),
      JSON.stringify(entry.duplicateTokenIds),
      entry.status,
      entry.timestamp,
      entry.prevHash,
      entry.hash,
    ],
  );
}

function toDomain(row: LedgerEntryRow): LedgerEntry {
  return LedgerEntry.rehydrate({
    ledgerId: row.ledger_id,
    eventType: row.event_type,
    merchantId: row.merchant_id,
    amount: unwrap(Money.fromPaise(Number(row.amount_paise))),
    acceptedTokenIds: row.accepted_token_ids,
    rejectedTokenIds: row.rejected_token_ids,
    duplicateTokenIds: row.duplicate_token_ids,
    status: row.status,
    timestamp: row.entry_timestamp,
    prevHash: row.prev_hash,
    hash: row.hash,
  });
}

/**
 * PgLedgerRepository — PostgreSQL adapter for the append-only Ledger context
 * (ARCHITECTURE.md §5.4, migration 005 `ledger_entries`). Only ever INSERTs —
 * `seq` (BIGSERIAL) gives a monotonic append order for headHash()/all(),
 * matching the in-memory array's push-order semantics. Replaces
 * InMemoryLedgerRepository.
 */
export class PgLedgerRepository implements LedgerRepository {
  constructor(private readonly pool: Pool) {}

  async append(entry: LedgerEntry): Promise<void> {
    await insertEntry(this.pool, entry);
  }

  async headHash(): Promise<string | null> {
    return readHeadHash(this.pool);
  }

  async appendAtomically(build: (prevHash: string | null) => LedgerEntry): Promise<LedgerEntry> {
    return withTransaction(async (client) => {
      // Serialize concurrent appends: without this lock, two transactions
      // could both read the same head hash before either inserts, so both
      // entries would chain to the same predecessor (a fork), silently
      // breaking the tamper-evidence guarantee. The lock is released
      // automatically at COMMIT/ROLLBACK (it's an xact-scoped lock), so it
      // never outlives this transaction.
      await client.query('SELECT pg_advisory_xact_lock($1)', [LEDGER_APPEND_LOCK_KEY]);
      const prevHash = await readHeadHash(client);
      const entry = build(prevHash);
      await insertEntry(client, entry);
      return entry;
    });
  }

  async findById(ledgerId: string): Promise<LedgerEntry | null> {
    const { rows } = await this.pool.query<LedgerEntryRow>(
      'SELECT * FROM ledger_entries WHERE ledger_id = $1',
      [ledgerId],
    );
    return rows[0] ? toDomain(rows[0]) : null;
  }

  async all(): Promise<LedgerEntry[]> {
    const { rows } = await this.pool.query<LedgerEntryRow>('SELECT * FROM ledger_entries ORDER BY seq ASC');
    return rows.map(toDomain);
  }
}
