import { Pool } from 'pg';
import { unwrap } from '../../../shared/result';
import { Money } from '../../../shared/money';
import { LedgerEntry, SettlementLedgerStatus } from '../domain/ledger_entry';
import { LedgerRepository } from '../domain/ledger_repository';

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
    await this.pool.query(
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

  async headHash(): Promise<string | null> {
    const { rows } = await this.pool.query<{ hash: string }>(
      'SELECT hash FROM ledger_entries ORDER BY seq DESC LIMIT 1',
    );
    return rows[0]?.hash ?? null;
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
