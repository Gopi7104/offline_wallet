import { RiskFlag } from '../domain/risk_flag';
import { RiskFlagRepository } from '../domain/risk_flag_repository';

/** In-memory RiskFlagRepository — tests only. */
export class InMemoryRiskFlagRepository implements RiskFlagRepository {
  private readonly flags: RiskFlag[] = [];

  async raise(flag: RiskFlag): Promise<void> {
    this.flags.push(flag);
  }

  async countAll(): Promise<number> {
    return this.flags.length;
  }

  /** Test helper: read back everything raised. */
  all(): ReadonlyArray<RiskFlag> {
    return this.flags;
  }
}
