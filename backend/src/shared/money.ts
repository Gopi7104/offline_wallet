import { InvariantViolation } from './errors';
import { Result, ok, err } from './result';

/**
 * Money — the foundational value object (ARCHITECTURE.md §4.2, ADR-4).
 *
 * Amounts are stored and computed as integer **paise** (₹1 = 100 paise),
 * never floats, to eliminate rounding error in a value-bearing ledger.
 * Currency is INR only (NFR-LEG-03). Immutable.
 */
export const CURRENCY = 'INR' as const;
export type Currency = typeof CURRENCY;

export const PAISE_PER_RUPEE = 100;

export class Money {
  private constructor(
    /** Amount in paise. Always a non-negative integer for wallet values. */
    readonly paise: number,
    readonly currency: Currency,
  ) {}

  /** Construct from an integer paise amount. */
  static fromPaise(paise: number): Result<Money, InvariantViolation> {
    if (!Number.isInteger(paise)) {
      return err(new InvariantViolation(`Money.paise must be an integer, got ${paise}`));
    }
    if (paise < 0) {
      return err(new InvariantViolation(`Money.paise must be non-negative, got ${paise}`));
    }
    return ok(new Money(paise, CURRENCY));
  }

  /** Construct from whole rupees (integer). Convenience for denominations. */
  static fromRupees(rupees: number): Result<Money, InvariantViolation> {
    if (!Number.isInteger(rupees)) {
      return err(new InvariantViolation(`Money.fromRupees expects an integer, got ${rupees}`));
    }
    return Money.fromPaise(rupees * PAISE_PER_RUPEE);
  }

  static zero(): Money {
    return new Money(0, CURRENCY);
  }

  add(other: Money): Money {
    return new Money(this.paise + other.paise, CURRENCY);
  }

  /** Subtract; fails rather than producing a negative value. */
  subtract(other: Money): Result<Money, InvariantViolation> {
    return Money.fromPaise(this.paise - other.paise);
  }

  equals(other: Money): boolean {
    return this.paise === other.paise && this.currency === other.currency;
  }

  isZero(): boolean {
    return this.paise === 0;
  }

  /** Human-readable, e.g. "₹5.00". Presentation only. */
  format(): string {
    const rupees = (this.paise / PAISE_PER_RUPEE).toFixed(2);
    return `₹${rupees}`;
  }
}
