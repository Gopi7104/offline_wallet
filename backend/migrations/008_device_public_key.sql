-- Owner-signed offline transfers (FR-PAY-04, FR-ID-02/03): each device owns
-- an Ed25519 keypair; the public key is uploaded through the existing Device
-- Registration flow (migration 006 `device_registrations`) so a merchant/
-- settlement can eventually be extended to check it, and so the registry
-- records which key currently proves ownership for a given device.
--
-- Nullable: rows inserted before this migration (or, in principle, by a
-- caller that predates the key requirement) never violate the constraint.
-- Every registration from the current app always supplies one (enforced at
-- the HTTP boundary, not here).
ALTER TABLE device_registrations
  ADD COLUMN public_key TEXT,
  ADD CONSTRAINT device_registrations_public_key_hex
    CHECK (public_key IS NULL OR public_key ~ '^[0-9a-fA-F]{64}$');
