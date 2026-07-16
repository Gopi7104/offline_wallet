-- Issuance (Mint) context (ARCHITECTURE.md §4.1, §4.3).
-- One row per minted token (digital cash coin). Status follows the lifecycle
-- in issuance/domain/token.ts: minted -> in_wallet -> in_transit -> redeemed
-- (or expired/voided).

CREATE TABLE tokens (
  token_id            TEXT PRIMARY KEY,
  denomination_paise  BIGINT NOT NULL,
  owner_id            TEXT NOT NULL,
  issued_at           TIMESTAMPTZ NOT NULL,
  expiry              TIMESTAMPTZ NOT NULL,
  status              TEXT NOT NULL,
  bank_signature      TEXT NOT NULL,
  CONSTRAINT tokens_denomination_positive CHECK (denomination_paise > 0),
  CONSTRAINT tokens_status_valid CHECK (
    status IN ('minted', 'in_wallet', 'in_transit', 'redeemed', 'expired', 'voided')
  )
);

CREATE INDEX idx_tokens_owner_id ON tokens (owner_id);
