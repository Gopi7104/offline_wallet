-- Identity & Device context (production hardening §1) — operational device
-- inventory: which devices exist, what they are, when they were last seen.
--
-- Deliberately named `device_registrations`, NOT `devices` — ARCHITECTURE.md
-- §5.2 already reserves `devices` for the future cryptographic device-binding
-- feature (public_key, attestation, op_counter_seen, one-active-device
-- partial-unique index; FR-ID-02/03/04, still open per docs/TODO.md). This
-- table is unrelated to that: multiple active devices per account are
-- expected and allowed here.

CREATE TABLE device_registrations (
  device_id      TEXT PRIMARY KEY,
  account_id     TEXT NOT NULL,
  platform       TEXT NOT NULL,
  device_model   TEXT NOT NULL,
  app_version    TEXT NOT NULL,
  registered_at  TIMESTAMPTZ NOT NULL,
  last_seen_at   TIMESTAMPTZ NOT NULL,
  active         BOOLEAN NOT NULL DEFAULT true,
  CONSTRAINT device_registrations_platform_valid CHECK (platform IN ('android', 'ios', 'web'))
);

CREATE INDEX idx_device_registrations_account_id ON device_registrations (account_id);
CREATE INDEX idx_device_registrations_active_last_seen ON device_registrations (active, last_seen_at);
