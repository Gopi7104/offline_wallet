-- Risk & Compliance context (ARCHITECTURE.md §4.1; production hardening §2).
-- Owned entirely by Risk — Settlement/Wallet never query these tables
-- directly, only through RiskEngine (application/risk_engine.ts).

-- Rolling history of accepted offline payments per payer, backing the
-- cumulative/daily-count/velocity limit checks (FR-RSK-02).
CREATE TABLE risk_payer_activity (
  seq          BIGSERIAL PRIMARY KEY,
  account_id   TEXT NOT NULL,
  amount_paise BIGINT NOT NULL,
  occurred_at  TIMESTAMPTZ NOT NULL,
  CONSTRAINT risk_payer_activity_amount_nonneg CHECK (amount_paise >= 0)
);

CREATE INDEX idx_risk_payer_activity_account_time ON risk_payer_activity (account_id, occurred_at);

-- Fraud/anomaly review records (FR-RSK-05/06) — one row per risk-rule
-- rejection. Append-only; no resolve/dismiss flow in this pass.
CREATE TABLE risk_flags (
  id           TEXT PRIMARY KEY,
  subject_type TEXT NOT NULL,
  subject_id   TEXT NOT NULL,
  reason_code  TEXT NOT NULL,
  message      TEXT NOT NULL,
  severity     TEXT NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL,
  CONSTRAINT risk_flags_subject_type_valid CHECK (subject_type IN ('account', 'device')),
  CONSTRAINT risk_flags_severity_valid CHECK (severity IN ('low', 'medium', 'high'))
);

CREATE INDEX idx_risk_flags_subject ON risk_flags (subject_type, subject_id);
