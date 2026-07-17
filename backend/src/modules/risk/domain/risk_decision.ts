/**
 * RiskDecision — the outcome of a single risk rule evaluation (Risk &
 * Compliance context, ARCHITECTURE.md §4.1). Every rule (wallet balance cap,
 * single-payment cap, cumulative/daily/velocity limits) returns one of these;
 * callers (Wallet, Settlement) only branch on `allowed`, never reimplement
 * the threshold comparison themselves — that decision stays inside Risk.
 */
export interface RiskDecision {
  readonly allowed: boolean;
  readonly reasonCode?: string;
  readonly message?: string;
}

export const ALLOWED: RiskDecision = { allowed: true };
