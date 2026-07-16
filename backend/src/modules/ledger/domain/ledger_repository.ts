import { LedgerEntry } from './ledger_entry';

/**
 * LedgerRepository — port for the append-only ledger (ARCHITECTURE.md §5.1,
 * §5.4). The log is immutable: the only write is `append`. Reads never mutate.
 * Domain defines the interface; infrastructure implements it.
 */
export interface LedgerRepository {
  /** Append an entry to the tail of the log. */
  append(entry: LedgerEntry): Promise<void>;
  /** Hash of the most recent entry, or null if the log is empty (chaining). */
  headHash(): Promise<string | null>;
  /** Fetch a single entry by its ledger id, or null. */
  findById(ledgerId: string): Promise<LedgerEntry | null>;
  /** All entries in append order (read model / history). */
  all(): Promise<LedgerEntry[]>;
}
