-- Settlement (Redemption) context (ARCHITECTURE.md §4.1, §5.2, §9; FR-SET-*).
--
-- spent_tokens is the double-spend enforcer (D3, ADR-7): the UNIQUE primary
-- key on token_id is what makes the first settlement to claim a token win
-- deterministically — a second INSERT of the same token_id is rejected by
-- Postgres itself, not by application code (settlement/infra/pg_spent_token_index.ts
-- uses `ON CONFLICT (token_id) DO NOTHING` and checks rowCount).
--
-- merchant_settlement_balances is the authoritative settled balance per
-- merchant (owned here, not by Identity's MerchantProfile projection — see
-- identity/domain/merchant_profile.ts comment). settlement_records is an
-- append-only history of every settlement attempt.

CREATE TABLE spent_tokens (
  token_id    TEXT PRIMARY KEY,
  claimed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE merchant_settlement_balances (
  merchant_id    TEXT PRIMARY KEY,
  settled_paise  BIGINT NOT NULL DEFAULT 0,
  CONSTRAINT merchant_settlement_balances_nonneg CHECK (settled_paise >= 0)
);

CREATE TABLE settlement_records (
  seq                    BIGSERIAL PRIMARY KEY,
  settlement_id          TEXT NOT NULL UNIQUE,
  merchant_id            TEXT NOT NULL,
  accepted_token_ids     JSONB NOT NULL,
  rejected_token_ids     JSONB NOT NULL,
  duplicate_token_ids    JSONB NOT NULL,
  credited_amount_paise  BIGINT NOT NULL,
  ledger_id              TEXT NOT NULL,
  status                 TEXT NOT NULL,
  settled_at             TIMESTAMPTZ NOT NULL,
  CONSTRAINT settlement_records_credited_nonneg CHECK (credited_amount_paise >= 0),
  CONSTRAINT settlement_records_status_valid CHECK (status IN ('SUCCESS', 'PARTIAL', 'REJECTED'))
);

CREATE INDEX idx_settlement_records_merchant_id ON settlement_records (merchant_id);
