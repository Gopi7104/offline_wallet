import { Pool } from 'pg';
import { unwrap } from '../../../shared/result';
import { Money } from '../../../shared/money';
import { MerchantProfile, MerchantWallet } from '../domain/merchant_profile';
import { MerchantRepository } from '../domain/merchant_repository';

interface MerchantProfileRow {
  merchant_id: string;
  account_id: string;
  display_name: string;
  pending_settlement_paise: string;
  settled_paise: string;
  created_at: Date;
}

function toDomain(row: MerchantProfileRow): MerchantProfile {
  const wallet = new MerchantWallet(
    unwrap(Money.fromPaise(Number(row.pending_settlement_paise))),
    unwrap(Money.fromPaise(Number(row.settled_paise))),
  );
  return new MerchantProfile(row.merchant_id, row.account_id, row.display_name, wallet, row.created_at);
}

/**
 * PgMerchantRepository — PostgreSQL adapter for the Identity & Device context's
 * Merchant Mode (ARCHITECTURE.md §5.2 `merchant_profiles`, migration 001).
 * Replaces InMemoryMerchantRepository; same port, same semantics.
 */
export class PgMerchantRepository implements MerchantRepository {
  constructor(private readonly pool: Pool) {}

  async findByAccountId(accountId: string): Promise<MerchantProfile | null> {
    const { rows } = await this.pool.query<MerchantProfileRow>(
      'SELECT * FROM merchant_profiles WHERE account_id = $1',
      [accountId],
    );
    return rows[0] ? toDomain(rows[0]) : null;
  }

  async findByMerchantId(merchantId: string): Promise<MerchantProfile | null> {
    const { rows } = await this.pool.query<MerchantProfileRow>(
      'SELECT * FROM merchant_profiles WHERE merchant_id = $1',
      [merchantId],
    );
    return rows[0] ? toDomain(rows[0]) : null;
  }

  async save(profile: MerchantProfile): Promise<void> {
    await this.pool.query(
      `INSERT INTO merchant_profiles
         (merchant_id, account_id, display_name, pending_settlement_paise, settled_paise, created_at)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (merchant_id) DO UPDATE SET
         display_name = EXCLUDED.display_name,
         pending_settlement_paise = EXCLUDED.pending_settlement_paise,
         settled_paise = EXCLUDED.settled_paise`,
      [
        profile.merchantId,
        profile.accountId,
        profile.displayName,
        profile.wallet.pendingSettlement.paise,
        profile.wallet.settled.paise,
        profile.createdAt,
      ],
    );
  }
}
