-- Ledger context (ARCHITECTURE.md §4.1, §5.4; FR-LED-01/02/03).
-- Append-only, hash-chained event log — never UPDATEd or DELETEd by the
-- application (ledger/infra/pg_ledger_repository.ts only INSERTs). `seq`
-- gives a monotonic, gap-free append order for headHash()/all(), independent
-- of `timestamp` (which is caller-supplied and only accurate to the clock
-- port's resolution).

CREATE TABLE ledger_entries (
  seq                  BIGSERIAL PRIMARY KEY,
  ledger_id            TEXT NOT NULL UNIQUE,
  event_type           TEXT NOT NULL,
  merchant_id          TEXT NOT NULL,
  amount_paise         BIGINT NOT NULL,
  accepted_token_ids   JSONB NOT NULL,
  rejected_token_ids   JSONB NOT NULL,
  duplicate_token_ids  JSONB NOT NULL,
  status               TEXT NOT NULL,
  entry_timestamp      TIMESTAMPTZ NOT NULL,
  prev_hash            TEXT,
  hash                 TEXT NOT NULL,
  CONSTRAINT ledger_entries_amount_nonneg CHECK (amount_paise >= 0),
  CONSTRAINT ledger_entries_status_valid CHECK (status IN ('SUCCESS', 'PARTIAL', 'REJECTED'))
);
