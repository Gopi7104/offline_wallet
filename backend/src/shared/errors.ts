/**
 * Domain error taxonomy. Expected, named failures returned via Result
 * (ARCHITECTURE.md §11) — e.g. ExactAmountImpossible, CoinAlreadySpent.
 * Feature-specific errors are added by their modules in later tasks.
 */
export abstract class DomainError extends Error {
  abstract readonly code: string;
  constructor(message: string) {
    super(message);
    this.name = new.target.name;
  }
}

/** A value object was constructed with input that violates an invariant. */
export class InvariantViolation extends DomainError {
  readonly code = 'INVARIANT_VIOLATION';
}
