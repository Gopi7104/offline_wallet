import { RiskFlag } from './risk_flag';

/** RiskFlagRepository — port. Domain defines the interface; infrastructure implements it. */
export interface RiskFlagRepository {
  raise(flag: RiskFlag): Promise<void>;
  /** Total flags ever raised — backs the monitoring/metrics endpoint. */
  countAll(): Promise<number>;
}
