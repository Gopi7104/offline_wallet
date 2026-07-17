import { LedgerEntry } from '../domain/ledger_entry';
import { LedgerRepository } from '../domain/ledger_repository';

/**
 * InMemoryLedgerRepository — adapter for Task 9 (before PostgreSQL).
 * Append-only: entries are pushed and never removed or overwritten. A later
 * task swaps this for an append-only Postgres table.
 */
export class InMemoryLedgerRepository implements LedgerRepository {
  private readonly entries: LedgerEntry[] = [];
  private readonly byId = new Map<string, LedgerEntry>();

  async append(entry: LedgerEntry): Promise<void> {
    this.entries.push(entry);
    this.byId.set(entry.ledgerId, entry);
  }

  async headHash(): Promise<string | null> {
    const last = this.entries[this.entries.length - 1];
    return last ? last.hash : null;
  }

  // No `await` between reading the head and pushing, so — unlike the Postgres
  // adapter — there is no interleaving window to guard against here; a plain
  // synchronous read-then-push is already atomic on Node's single thread.
  async appendAtomically(build: (prevHash: string | null) => LedgerEntry): Promise<LedgerEntry> {
    const entry = build(await this.headHash());
    await this.append(entry);
    return entry;
  }

  async findById(ledgerId: string): Promise<LedgerEntry | null> {
    return this.byId.get(ledgerId) ?? null;
  }

  async all(): Promise<LedgerEntry[]> {
    // Return a copy so callers cannot mutate the internal log.
    return [...this.entries];
  }

  /** Test helper: reset the log. */
  clear(): void {
    this.entries.length = 0;
    this.byId.clear();
  }
}
