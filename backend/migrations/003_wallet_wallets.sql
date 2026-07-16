-- Wallet (server shadow) context (ARCHITECTURE.md §4.1, §6.2).
-- The Wallet aggregate (wallet/domain/wallet.ts) is `{ accountId, tokens[] }`;
-- `save()` replaces the account's full token set, so wallet_tokens mirrors
-- that aggregate exactly (one row per token currently held in the wallet
-- snapshot). This is a separate store from `tokens` (Issuance's own record of
-- every minted token) by design — the two contexts own their data
-- independently and communicate only through application-layer calls
-- (ARCHITECTURE.md §4: "never by reaching into each other's tables").

CREATE TABLE wallets (
  account_id  TEXT PRIMARY KEY,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE wallet_tokens (
  token_id            TEXT PRIMARY KEY,
  account_id          TEXT NOT NULL REFERENCES wallets (account_id) ON DELETE CASCADE,
  denomination_paise  BIGINT NOT NULL,
  owner_id            TEXT NOT NULL,
  issued_at           TIMESTAMPTZ NOT NULL,
  expiry              TIMESTAMPTZ NOT NULL,
  status              TEXT NOT NULL,
  bank_signature      TEXT NOT NULL,
  CONSTRAINT wallet_tokens_denomination_positive CHECK (denomination_paise > 0),
  CONSTRAINT wallet_tokens_status_valid CHECK (
    status IN ('minted', 'in_wallet', 'in_transit', 'redeemed', 'expired', 'voided')
  )
);

CREATE INDEX idx_wallet_tokens_account_id ON wallet_tokens (account_id);
