-- Identity & Device context (ARCHITECTURE.md §4.1, §5.2).
-- Merchant Mode is a role on an Account (FR-MER-01): one merchant profile per
-- account_id. pending_settlement_paise / settled_paise are a read projection
-- only (see identity/domain/merchant_profile.ts) — the authoritative settled
-- balance lives in merchant_settlement_balances (Settlement context, 004).

CREATE TABLE merchant_profiles (
  merchant_id               TEXT PRIMARY KEY,
  account_id                TEXT NOT NULL UNIQUE,
  display_name              TEXT NOT NULL,
  pending_settlement_paise  BIGINT NOT NULL DEFAULT 0,
  settled_paise             BIGINT NOT NULL DEFAULT 0,
  created_at                TIMESTAMPTZ NOT NULL,
  CONSTRAINT merchant_profiles_pending_nonneg CHECK (pending_settlement_paise >= 0),
  CONSTRAINT merchant_profiles_settled_nonneg CHECK (settled_paise >= 0)
);
