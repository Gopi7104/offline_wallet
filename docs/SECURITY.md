# Security & Threat Model — Offline Digital Cash Wallet

**Version 1.0 | Status: Proposal | Last updated: 2026-07-13**

This document is the formal security analysis for the Offline Digital Cash Wallet prototype. It defines the security principles, trust boundaries, cryptography, key management, a **STRIDE** threat model, and the honest limitations we accept (design decision **D3**). It implements the `NFR-SEC-*` / `NFR-CRY-*` requirements in [REQUIREMENTS.md](REQUIREMENTS.md) and refines [ARCHITECTURE.md](ARCHITECTURE.md) §10. Protocol-level defenses are specified in [PAYMENT_PROTOCOL.md](PAYMENT_PROTOCOL.md).

The guiding stance is **honest security**: we state plainly what we prevent, what we only detect, and what we accept as residual risk.

---

## 1. Security Principles

| Principle | Meaning here |
|-----------|--------------|
| **Verify before value** | No value is minted, transferred, or credited until every relevant signature verifies — offline at receipt (merchant) and online at settlement (server) (NFR-SEC-03). |
| **Keys never leave their boundary** | Issuer key stays in server KMS/HSM; device key stays in the platform keystore, non-exportable (NFR-SEC-02). |
| **Detect what you cannot prevent** | Software on a consumer phone cannot prevent rollback/cloning; we detect it server-side and bound the loss (D3, NFR-SEC-07). |
| **Bound the blast radius** | Offline value/velocity limits + single-hop circulation cap the loss from any one compromised device (D1, FR-RSK). |
| **Defense in depth** | Device binding, attestation, root detection, rollback tripwire, and blacklist layer so no single failure is catastrophic. |
| **Least trust in transport** | BLE link security is never trusted alone; authentication and integrity are enforced at the application layer (NFR-SEC-05). |
| **Auditability** | An append-only, hash-chained ledger makes every value movement attributable and tamper-evident (FR-LED-01). |

---

## 2. Assets (What We Protect)

| Asset | Why it matters | Primary protection |
|-------|----------------|--------------------|
| **Bank Issuer private key** | Signs all coins; compromise = unlimited counterfeit money | KMS/HSM custody, never in app/DB (NFR-SEC-02) |
| **Device private key** | Signs transfers = authorizes spending | Non-exportable platform keystore |
| **Wallet data-at-rest** | Holds spendable coins | AES-256-GCM, key wrapped by keystore (NFR-SEC-01) |
| **Coins in flight (BLE/QR)** | Bearer-ish value in transit | App-layer signatures + freshness + nonce binding |
| **The ledger** | System of record for all money | Append-only, hash-chained, DB constraints |
| **Money-supply invariant** | Guarantees no value is created/destroyed | Reconciliation job + spent-coin index (FR-LED-03) |
| **User PII / transaction graph** | Privacy | Minimization, access control (NFR-DAT-02); note: not anonymous (NFR-DAT-01) |

---

## 3. Trust Boundaries

```
 ┌────────────────────────── DEVICE ──────────────────────────┐
 │  (1) Platform keystore  ──►  device key (non-exportable)    │
 │  (2) Encrypted wallet   ──►  coins at rest (AES-256-GCM)    │
 │  (3) App process        ──►  plaintext coins in memory      │
 └───────┬───────────────────────────────────┬────────────────┘
         │ (4) App-layer secure channel        │ (5) TLS
         │     over BLE / QR (offline)          │
   ┌─────▼─────┐                          ┌─────▼──────────────┐
   │  Merchant │                          │  Backend (server)  │
   │  device   │                          │  + (6) KMS/HSM     │
   └───────────┘                          └────────────────────┘
```

Value crosses a boundary **only** with a verified signature. Boundary (3) — plaintext in the app process — is the weakest on a compromised device and drives the D3 limitation (§6).

---

## 4. Cryptography

| Purpose | Primitive | Notes |
|---------|-----------|-------|
| Coin issuance & transfer signatures | **Ed25519** | Well-audited; libsodium / tweetnacl; no custom primitives (NFR-CRY-01/03) |
| Wallet encryption at rest | **AES-256-GCM** | Authenticated encryption; per-record nonces (NFR-SEC-01) |
| Key derivation | **HKDF** | Derive wallet data key; wrapped by keystore key |
| Wallet integrity tag | **HMAC-SHA-256** (or signature) | Over wallet state + op-counter (NFR-SEC-04) |
| Ledger tamper evidence | **SHA-256 hash chain** | `hash = H(prev_hash ‖ entry)` (FR-LED-01) |
| Randomness | **Platform CSPRNG** | Nonces, coin IDs, keys (NFR-CRY-01) |

**Key hierarchy:** Issuer key (server/KMS) → signs coins; Device key (keystore) → signs transfers; Wallet data key (HKDF-derived, keystore-wrapped) → encrypts local storage.

**Issuer key rotation** is supported via `key_id`: each coin carries the `issuer_key_id` that signed it, and the app bundles a **set** of trusted issuer public keys so coins signed by any current-or-recent key verify offline (NFR-CRY-02).

---

## 5. Key Management

| Key | Storage | Lifecycle |
|-----|---------|-----------|
| **Bank Issuer** (Ed25519) | Cloud KMS/HSM (prod); encrypted local secret (dev). Never in app bundle or DB. Only the **public** key ships in the app. | Versioned by `key_id`; rotate on schedule/compromise; old public keys retained for verifying unexpired coins. |
| **Device** (Ed25519) | Platform keystore (Android Keystore / iOS Keychain + Secure Enclave), non-exportable, hardware-backed where available. | Generated on first launch post-auth (FR-ID-02); a **new** key is generated on device re-registration, invalidating the old binding (FR-ID-04). |
| **Wallet data key** (AES-256) | Derived via HKDF, wrapped by a keystore key; plaintext key exists only transiently in memory. | Rotated on re-key / major sync events. |

**Operational rules:** secrets are provisioned via the secret manager, never committed; logs never contain key material or full PII (NFR-SEC-08); dev and prod use distinct issuer keys so a leaked dev key cannot mint prod-trusted coins.

---

## 6. The Central Limitation (D3) — Detect, Don't Prevent

On a **rooted / jailbroken** device an attacker operating at boundary (3) can:

- extract the device private key at runtime (or sign arbitrary transfers with it in place),
- read plaintext coins from memory,
- **clone** the encrypted wallet + wrapped key to another device,
- **roll back** the wallet to a pre-spend backup and spend the same coins again,
- run a **modified app** that ignores client-side offline limits.

**Why software cannot prevent this:** consumer phones lack a reliable **secure monotonic counter** accessible to apps. Without hardware-backed rollback protection (StrongBox / Secure Enclave with a real counter, inconsistently available), an app cannot prove its state has not been rewound.

**What we do instead:**
1. **Detect at settlement** via the unique spent-coin index — the second redemption of any coin is caught deterministically (FR-SET-03/04).
2. **Bound the loss** with per-transaction, cumulative, and velocity limits, and single-hop circulation (FR-RSK, D1) — a compromised device can lose at most its offline allowance before it must reconnect.
3. **Attribute** the fraud — both double-spent copies carry the **same payer signature**, identifying the offender (FR-SET-04).
4. **Recover / punish** — first-valid-redemption wins; attempt clawback from the payer's bank account; else write-off + flag + blacklist repeat offenders (FR-SET-05, FR-RSK-05).

This is stated openly to users and operators (NFR-SEC-07, NFR-LEG-01).

---

## 7. STRIDE Threat Model

Threats are rated by residual risk **after** mitigation. "Prevented" = attack fails; "Detected" = attack succeeds once but is caught and bounded; "Accepted" = residual, documented.

### 7.1 Spoofing (identity)

| Threat | Mitigation | Residual |
|--------|-----------|----------|
| Fake user / stolen session | Firebase auth; backend independently verifies ID tokens (FR-ID-01). | Prevented |
| Impersonate another device | Device binding: pubkey registered to account; one active device (FR-ID-03/04). Transfers carry the device pubkey + signature. | Prevented (server-side) |
| Fake merchant in a QR/BLE handshake | Transfer binds `merchant_id`; a payer paying the wrong merchant still only credits whoever settles — but the merchant cannot impersonate a *different* merchant to steal credit, since settlement credits by the account that uploads with a valid device identity. | Low |
| Emulator / non-genuine app at registration | Attestation (Play Integrity / App Attest), risk-scored not hard-blocked in prototype (FR-ID-05). | Accepted (prototype) |

### 7.2 Tampering (integrity)

| Threat | Mitigation | Residual |
|--------|-----------|----------|
| Alter a coin (denom/expiry) | Issuer Ed25519 signature over coin fields; verified offline + at settlement (FR-PAY-05, NFR-SEC-03). | Prevented |
| Alter a transfer (amount/coins/merchant) | Payer signature over canonical `TransferSigningPayload`; `amount == Σ denom` checked (§PAYMENT_PROTOCOL 4.2, 6.4). | Prevented |
| Modify local wallet (add value/undo spend) | AES-256-GCM + HMAC integrity tag + monotonic op-counter; failed integrity/counter regression blocks spending (NFR-SEC-04, FR-WAL-04). | Prevented (integrity) / rollback → Detected at sync |
| Tamper with the ledger | Append-only + hash chain; reconciliation detects drift (FR-LED-01/04). | Detected |
| MITM alters BLE messages | App-layer signatures over canonical bytes; tampering invalidates signatures (NFR-SEC-05). | Prevented |

### 7.3 Repudiation

| Threat | Mitigation | Residual |
|--------|-----------|----------|
| Payer denies authorizing a payment | Non-repudiable payer signature over the Transfer (FR-PAY-04). | Prevented |
| Merchant denies receiving / disputes credit | Signed ACK + append-only ledger + local receipts on both sides (FR-HIS-01/02). | Prevented |
| "I never double-spent" | Both redemptions carry the same payer signature (FR-SET-04). | Prevented (attribution) |

### 7.4 Information Disclosure

| Threat | Mitigation | Residual |
|--------|-----------|----------|
| Wallet theft from device storage | Encrypted at rest; key in keystore (NFR-SEC-01). | Prevented (at rest) |
| Key extraction on rooted device | Non-exportable keystore raises the bar; hardware-backing where available. | Accepted on root (D3) |
| Eavesdrop BLE / QR | QR carries no secrets (FR-PAY-01); coins are bearer value but bound to `merchant_id + nonce`, so a captured transfer cannot be replayed elsewhere (NFR-SEC-06). TLS protects online paths. | Low |
| Secrets in logs | No key material / full PII in logs (NFR-SEC-08). | Prevented (by policy) |
| Transaction-graph privacy | **Explicitly not private** — server logs issuance/redemption for fraud detection (NFR-DAT-01). | Accepted (by design) |

### 7.5 Denial of Service

| Threat | Mitigation | Residual |
|--------|-----------|----------|
| BLE jamming / dropped link | Two-phase + retain-until-ACK: value never lost, payment simply retried; QR-only fallback (FR-PAY-06/11). | Low (availability only) |
| Nonce/replay flooding at a merchant | Single-use nonces, freshness window, cheap signature pre-checks. | Low |
| Settlement spam / duplicate uploads | Idempotency keys; unique spent-coin index; per-coin batch results (FR-SET-03/08). | Low |
| Server outage blocks payments | Payments are **offline by design**; only load/settlement need the server (NFR-REL-03). | Low |

### 7.6 Elevation of Privilege

| Threat | Mitigation | Residual |
|--------|-----------|----------|
| Modified app bypasses client-side limits | Limits re-validated server-side at sync; offline allowance reset only on sync; velocity flags (FR-RSK-02/03). Loss bounded by allowance. | Detected + bounded |
| Forge coins (mint without the bank) | Only the KMS-held issuer key can produce valid coin signatures (NFR-SEC-02). | Prevented |
| Re-spend received coins offline (multi-hop) | Single-hop: received coins are held-for-settlement, not offline-spendable (D1, FR-PAY-09). | Prevented |
| Escalate one account to control another's coins | Coins bound to owner via device signature; server authorizes per session. | Prevented |

---

## 8. Key Attack Scenarios (Walkthroughs)

**A. Clone-and-double-spend.** Attacker clones the wallet to two phones, pays Merchant X and Merchant Y the same coins offline. Both verify offline (both copies are valid!) and accept. At settlement, the first upload inserts into `spent_coins`; the second hits the UNIQUE violation → double-spend. First merchant keeps the value; second is rejected; clawback attempted from the payer; payer flagged/blacklisted (FR-SET-05, FR-RSK-05). **Loss is bounded by the offline allowance and attributed to the payer.**

**B. Replay to a second merchant.** Attacker captures a BLE transfer transcript and replays it to Merchant Z. The Transfer is bound to the original `merchant_id + nonce`; Z's nonce differs and Z rejects on `merchant_mismatch` / `nonce_unknown` (§PAYMENT_PROTOCOL 6.4, NFR-SEC-06). **Prevented.**

**C. Rollback after spending.** Attacker restores a pre-payment backup to reclaim spent coins and spends again. On next sync the device's op-counter is behind `wallet_shadows.op_counter` (or the state HMAC is stale) → rollback detected → risk flag / blacklist (FR-SYNC-05). The re-spent coins also collide at settlement (scenario A). **Detected + bounded.**

**D. Interrupted transfer.** Link drops after the payer sent OFFER but before it saw the ACK. Payer retains coins (no valid ACK). Merchant may or may not have persisted the proof; on reconnect the payer re-sends the same nonce and the merchant re-sends the stored ACK. Exactly-once by nonce dedup (FR-PAY-07). **No value lost or duplicated.**

---

## 9. Security Best Practices (Implementation)

- **Crypto:** use libsodium/tweetnacl; never hand-roll primitives (NFR-CRY-03). Sign canonical bytes, not transport text (§PAYMENT_PROTOCOL 3).
- **Constant-time** comparison for tags/signatures; rely on library verify functions.
- **Input validation** at every boundary: reject malformed coins/transfers before crypto work; enforce denomination set and paise-integer amounts.
- **Idempotency** on all value-mutating endpoints; SERIALIZABLE isolation (or unique-constraint conflict) for redemption (FR-SET-07).
- **No secrets in VCS or app bundle**; only issuer *public* keys ship in the app; distinct dev/prod issuer keys.
- **Structured logging** without secrets/PII; alert on money-supply invariant breach and abnormal double-spend rates (NFR-MNT-03).
- **Root/jailbreak detection** as a tripwire that raises a risk flag, not a hard block (FR-ID-06).
- **Minimum OS targets** (Android 10+ / iOS 14+) to guarantee keystore + BLE capability (NFR-CMP-03).

---

## 10. Residual Risks (Accepted & Documented)

| ID | Risk | Rating | Disposition |
|----|------|--------|-------------|
| R-1 | Rooted/cloned device double-spends within the offline allowance | High | Accepted (D3): detect at settlement, bound by limits, attribute + blacklist |
| R-2 | Device compromise = total loss of that wallet's cash | Medium | Accepted (A5): like losing a physical wallet; bounded by allowance |
| R-3 | No transaction-graph privacy | Medium | Accepted by design (NFR-DAT-01): fraud detection prioritized over anonymity |
| R-4 | Attestation not hard-enforced in prototype | Low | Accepted (prototype): risk-scored (FR-ID-05); harden for production |
| R-5 | Issuer key compromise = counterfeit money | Critical | Mitigated: KMS/HSM custody, rotation via `key_id`; out-of-band revocation if breached |

---

## 11. Traceability (security ↔ requirements)

| Security control | Satisfies |
|------------------|-----------|
| AES-256-GCM at rest, keystore-wrapped key (§4, §5) | NFR-SEC-01, FR-WAL-03 |
| Keys never leave boundary; KMS custody (§5) | NFR-SEC-02 |
| Verify-before-value, offline + online (§1, §7.2) | NFR-SEC-03, FR-PAY-05, FR-SET-02 |
| Integrity tag + op-counter, rollback tripwire (§7.2, §8C) | NFR-SEC-04, FR-WAL-04, FR-SYNC-05 |
| App-layer auth over BLE (§3, §7.2) | NFR-SEC-05 |
| Nonce + merchant + freshness anti-replay (§7.4, §8B) | NFR-SEC-06 |
| Documented D3 limitation (§6, §10) | NFR-SEC-07, NFR-LEG-01 |
| Ed25519/AES/HKDF, audited libs, key rotation (§4) | NFR-CRY-01/02/03 |
| Spent-coin index, first-valid-wins, attribution (§8A) | FR-SET-03/04/05 |
| Limits, blacklist, flagging (§6, §7.6) | FR-RSK-01..05 |

---

*Threat model for review. Update the STRIDE tables (§7) and residual-risk register (§10) whenever a trust boundary, key, or protocol message changes. Cross-check against [PAYMENT_PROTOCOL.md](PAYMENT_PROTOCOL.md) and [ARCHITECTURE.md](ARCHITECTURE.md) §10.*
