import { randomUUID } from 'crypto';

export type RiskSubjectType = 'account' | 'device';
export type RiskSeverity = 'low' | 'medium' | 'high';

/**
 * RiskFlag — a fraud/anomaly review record (ARCHITECTURE.md §4.1 "Risk &
 * Compliance"; FR-RSK-05/06). Raised whenever a risk rule rejects a payment
 * or wallet operation. Append-only in practice (no update/resolve flow in
 * this hardening pass — that is future Risk/Ops tooling). Immutable.
 */
export class RiskFlag {
  constructor(
    readonly id: string,
    readonly subjectType: RiskSubjectType,
    readonly subjectId: string,
    readonly reasonCode: string,
    readonly message: string,
    readonly severity: RiskSeverity,
    readonly createdAt: Date,
  ) {}

  static raise(
    subjectType: RiskSubjectType,
    subjectId: string,
    reasonCode: string,
    message: string,
    severity: RiskSeverity,
    now: Date,
  ): RiskFlag {
    return new RiskFlag(`RISK-${randomUUID()}`, subjectType, subjectId, reasonCode, message, severity, now);
  }
}
