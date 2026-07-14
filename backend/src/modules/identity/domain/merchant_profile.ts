import { Money } from '../../../shared/money';
import { randomUUID } from 'crypto';

/**
 * MerchantWallet — read projection of the two buckets a merchant cares about
 * (FR-MER-02): funds received but not yet settled, and funds already settled.
 *
 * OWNERSHIP (Architecture v1.1): the authoritative merchant balance is NOT
 * stored here. `settled` maps to `accounts.settlement_balance` and `pending`
 * to the `in_merchant_wallets_unsettled` money-supply bucket (§5.2, §5.4) —
 * both owned by the Settlement/Ledger contexts. Task 4 is a placeholder: both
 * buckets are zero until Settlement is implemented.
 * TODO(Settlement): source these from settlement_balance + the ledger bucket
 * rather than defaulting to zero. Immutable.
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
 * MerchantProfile — the Merchant *role* on an Account (FR-MER-01, §4.1:
 * "a user is a Customer and, in Merchant Mode, a Merchant"). This is NOT a
 * separate bounded context: enabling Merchant Mode attaches a merchant identity
 * and a (projected) wallet to an existing account, with no separate
 * registration. Owned by the Identity & Device context. Immutable.
 */
export class MerchantProfile {
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
  static create(accountId: string, displayName: string, now: Date): MerchantProfile {
    return new MerchantProfile(
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
