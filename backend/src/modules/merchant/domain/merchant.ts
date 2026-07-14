import { Money } from '../../../shared/money';
import { randomUUID } from 'crypto';

/**
 * MerchantWallet — value object holding the two buckets a merchant cares about
 * (FR-MER-02): funds received but not yet settled, and funds already settled.
 * Task 4: both start at zero; settlement (a later task) will move value from
 * pendingSettlement → settled. Immutable.
 */
export class MerchantWallet {
  constructor(
    readonly pendingSettlement: Money,
    readonly settled: Money,
  ) {}

  static empty(): MerchantWallet {
    return new MerchantWallet(Money.zero(), Money.zero());
  }

  /** Total value the merchant has taken in (pending + settled). */
  get total(): Money {
    return this.pendingSettlement.add(this.settled);
  }
}

/**
 * Merchant — aggregate root for Merchant Mode (FR-MER-01, ARCHITECTURE.md §4.1).
 * A Merchant is a *role* on an existing account: enabling Merchant Mode mints a
 * Merchant ID and an empty merchant wallet with no separate registration.
 * Task 4 scope: no cryptography, no bank binding, no settlement.
 * Immutable: any future state change returns a new Merchant.
 */
export class Merchant {
  constructor(
    readonly merchantId: string,
    readonly accountId: string,
    readonly displayName: string,
    readonly wallet: MerchantWallet,
    readonly createdAt: Date,
  ) {}

  /**
   * Enable Merchant Mode for an account. Generates a fresh Merchant ID and an
   * empty merchant wallet.
   */
  static create(accountId: string, displayName: string, now: Date): Merchant {
    return new Merchant(
      generateMerchantId(),
      accountId,
      displayName,
      MerchantWallet.empty(),
      now,
    );
  }
}

/**
 * Merchant ID generation. Format: "MER-" + 12 uppercase hex chars derived from
 * a CSPRNG UUID. The ID is public and non-secret — it is embedded in QR
 * payloads (FR-PAY-01) — so it carries no key material.
 */
export function generateMerchantId(): string {
  const hex = randomUUID().replace(/-/g, '').slice(0, 12).toUpperCase();
  return `MER-${hex}`;
}
