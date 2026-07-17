import { PayerActivityRepository } from '../domain/payer_activity_repository';

interface ActivityRecord {
  readonly accountId: string;
  readonly amountPaise: number;
  readonly occurredAt: Date;
}

/** In-memory PayerActivityRepository — tests only. */
export class InMemoryPayerActivityRepository implements PayerActivityRepository {
  private readonly records: ActivityRecord[] = [];

  async record(accountId: string, amountPaise: number, occurredAt: Date): Promise<void> {
    this.records.push({ accountId, amountPaise, occurredAt });
  }

  async sumSince(accountId: string, since: Date): Promise<number> {
    return this.records
      .filter((r) => r.accountId === accountId && r.occurredAt.getTime() >= since.getTime())
      .reduce((sum, r) => sum + r.amountPaise, 0);
  }

  async countSince(accountId: string, since: Date): Promise<number> {
    return this.records.filter((r) => r.accountId === accountId && r.occurredAt.getTime() >= since.getTime()).length;
  }
}
