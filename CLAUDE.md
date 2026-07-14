# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Offline Digital Cash Wallet** — a secure mobile payment platform enabling small-value transactions when internet, banking infrastructure, UPI, or cellular networks are unavailable.

- **Core concept:** digital cash as signed tokens (like physical cash), not a balance number.
- **Offline payment:** customer-to-merchant transfer via BLE/QR with cryptographic finality; settlement happens later.
- **Detection-over-prevention:** double-spend is *detected* at settlement, not *prevented* on-device (design decision D3).
- **Two-developer scope:** ~6–9 months to MVP (Phase 1: foundation + load; Phase 2: offline protocol; Phase 3–4: settlement + limits; Phase 5–6: hardening).

**Not in scope:** real money, multi-hop circulation, offline refunds, anonymity, NFC, multi-currency.

---

## Architecture Summary

### Backend (Node.js + Express + TypeScript)

**Modular monolith** with seven bounded contexts:

1. **Identity & Device** — Firebase auth, device key registration, one-active-device enforcement.
2. **Issuance (Mint)** — atomic load (debit bank, mint coins, ledger entry).
3. **Wallet (server shadow)** — tracks last-synced state, op-counter, offline allowance.
4. **Payment / Transfer** — validates owner-signed transfers at settlement.
5. **Settlement (Redemption)** — exactly-once via unique `coin_id` index; detects double-spend.
6. **Ledger** — append-only, immutable event log (hash-chained for tamper evidence).
7. **Risk & Compliance** — fraud flags, device blacklist, velocity limits.

**Persistence:** PostgreSQL with critical constraints:
- `spent_coins` has a UNIQUE index on `coin_id` (double-spend detection).
- `devices` has a partial unique index on `(account_id, active=true)` (one device per user).
- All value movements are atomic (single DB transaction).
- Idempotency keys prevent duplicate processing.

**Key tables:** accounts, devices, coins, transfers, spent_coins (the enforcer), ledger_entries, wallet_shadows, risk_flags.

### Mobile (Flutter + Dart)

**Feature-first clean architecture**, offline-first:

```
core/          crypto ports, money types, errors, clock
platform/      keystore (Android Keystore / iOS Keychain), BLE, QR
data/          local encrypted DB (SQLCipher), repositories, sync engine
domain/        entities (Coin, Transfer, Wallet), use cases, interfaces
features/      auth, wallet (load, balance), pay (scan, send), receive (merchant), history
app/           routing, DI, theming
```

**Local storage:** Drift + SQLCipher (encrypted), with HMAC-signed state + monotonic op-counter for rollback detection.

**State management:** Riverpod (recommend) or Bloc for testable, compile-safe DI.

**Platform integration:** 
- Android: Android Keystore (hardware-backed if available), BLE via `flutter_blue_plus`.
- iOS: Keychain + Secure Enclave, Core Bluetooth.

### Offline Payment Protocol

**Two-phase, atomic exchange** (no value lost on interrupted BLE):

1. Merchant generates QR with `{merchant_id, nonce, timestamp}`.
2. Payer scans, selects exact-amount coin set (fine denominations: {1,2,5,10,20,50,100,200,500} INR), signs Transfer.
3. Payer sends Transfer + coins via BLE; merchant verifies offline (issuer sig, owner sig, nonce freshness, expiry).
4. Merchant returns signed ACK; payer deletes coins **only** after valid ACK (atomicity).
5. Dedup by nonce prevents retried connections from double-spending.

See [PAYMENT_PROTOCOL.md](docs/PAYMENT_PROTOCOL.md) for wire format.

---

## Design Decisions (Baked In)

| # | Decision | Implication |
|---|----------|-------------|
| **D1** | Single-hop (no coin re-circulation offline) | Received coins must be settled before re-spending; limits double-spend blast radius. |
| **D2** | Fine denominations + no change | Payer's app assembles exact amount; merchants never give change. Requires denomination selection algorithm. |
| **D3** | Detect-at-settlement (software + fraud flagging) | A rooted/cloned device can double-spend; we detect it via the unique spent-coin index and flag the payer. This is an accepted, documented limitation. |
| **D4** | Flutter targeting both Android + iOS | One codebase, two platforms. Requires platform channels for keystore. |

---

## Key Files & Documentation

### Design & Planning (Read These First)

- **[PROJECT_VISION.md](docs/PROJECT_VISION.md)** — Executive vision, problem statement, design principles, token model, offline flow, security model, roadmap (high-level phase breakdown).
- **[REQUIREMENTS.md](docs/REQUIREMENTS.md)** — Functional (FR-*) and non-functional (NFR-*) requirements with MoSCoW priorities. All acceptance criteria here.
- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** — Detailed architecture (containers, DDD contexts, data model, API contracts, traceability to requirements).
- **[SECURITY.md](docs/SECURITY.md)** — Full threat model (what we prevent, what we detect, what is documented limitation).
- **[PAYMENT_PROTOCOL.md](docs/PAYMENT_PROTOCOL.md)** — Wire protocol, message formats, state machines for offline exchange.

### Implementation Guidance

- **Backend roadmap:** Phase 1 (crypto + token models), Phase 2 (wallet load), Phase 3 (offline protocol), Phase 4 (settlement + ledger), Phase 5 (limits + risk), Phase 6 (tests + hardening). See PROJECT_VISION §9.
- **Architecture patterns:**
  - Hexagonal (ports-and-adapters) for dependency injection.
  - Domain-driven design: bounded contexts, aggregates, value objects, domain services.
  - Event-sourced ledger (append-only, hash-chained, never mutated).
  - Operational projections (state tables) reconciled against ledger.
  - Outbox pattern for reliable async events.

---

## Cryptocurrency & Signing (Critical)

### Algorithms & Libraries

- **Signatures:** Ed25519 (libsodium / tweetnacl).
- **Symmetric encryption:** AES-256-GCM.
- **Key derivation:** HKDF.
- **RNG:** Platform CSPRNG.

### Key Management

| Key | Location | Use |
|-----|----------|-----|
| **Bank Issuer Key** | Server KMS/HSM (never in app or DB) | Signs every coin. Public key pinned in app for offline verification. |
| **Device Key** | Platform Keystore (Android Keystore / iOS Keychain), non-exportable | Signs transfers (proves ownership). New key on device re-registration. |
| **Wallet Data Key** | Derived (HKDF), wrapped by keystore key | Encrypts local wallet at rest. |

**Rule:** All signature verification happens before value is accepted (offline at receipt, online at settlement).

---

## Money & Amounts

- **Unit:** integer **paise** (₹1 = 100 paise), never floats. Prevents rounding error in a ledger.
- **Currency:** INR only.
- **Limits (configurable, server-driven):**
  - Per-transaction: ₹5,000 default.
  - Cumulative offline: ₹50,000 default.
  - Velocity: 5 offline payments / 24h rolling default.

Limits are enforced client-side (blocking offline payment) and re-validated server-side at sync; reset only on successful sync.

---

## Database Constraints (Non-Negotiable)

These are not optional. They enforce financial invariants:

```sql
-- Exactly-once redemption
CREATE UNIQUE INDEX idx_spent_coins_coin_id ON spent_coins(coin_id);

-- One active device per account
CREATE UNIQUE INDEX idx_devices_active_per_account 
  ON devices(account_id) WHERE active = true;

-- All value movements must be atomic and logged
-- (enforced via single TX + outbox pattern)
```

---

## Testing & Verification Strategy

### Property Tests (Essential)

- **Double-spend detection:** two concurrent uploads of the same coin → first wins deterministically, second rejected.
- **Replay prevention:** same transfer message to two merchants → second rejected due to nonce binding + merchant-side persistence.
- **Money-supply invariant:** after any workload, `issued = outstanding + redeemed + expired + written_off`.
- **Offline atomicity:** interrupted BLE transfer → value neither lost nor duplicated (two-phase + dedup by nonce).

### Integration Tests

- End-to-end offline payment: load → offline → transfer → merchant receives → settlement credits.
- Rollback detection: device claims regressed op-counter → flagged and blacklisted.
- Sync idempotency: same sync request replayed → no double-credit.

---

## Development Workflow

### Backend Setup (Phase 1)

1. Initialize Node.js + Express + TypeScript project.
2. Set up PostgreSQL locally (Docker Compose or managed).
3. Implement domain layer: `Money`, `Coin`, `Transfer`, `Signature` value objects.
4. Implement crypto ports (Signer, Verifier, KeyStore) with libsodium adapters.
5. Stub API endpoints with auth + Firebase token verification.

### Mobile Setup (Phase 1)

1. Create Flutter project, target Android 10+ and iOS 14+.
2. Implement platform channels: keystore key gen (Android Keystore, iOS Keychain).
3. Set up local encrypted database (Drift + SQLCipher).
4. Implement domain: `Coin`, `Transfer`, `Wallet` entities.

### Per-Phase Deliverables

- **Phase 1:** foundation, crypto tests, token models ✓ (docs done; code pending).
- **Phase 2:** load endpoint, wallet encryption, sync framework.
- **Phase 3:** QR generation, BLE exchange, offline payment protocol.
- **Phase 4:** settlement endpoint, spent-coin index, double-spend detection, ledger.
- **Phase 5:** offline limits, velocity enforcement, risk flagging, device blacklist.
- **Phase 6:** test coverage >70%, security audit, documentation, hardening.

---

## Common Development Tasks

### Adding a New Requirement/Feature

1. **Read the requirement ID** (FR-* or NFR-*) in [REQUIREMENTS.md](docs/REQUIREMENTS.md).
2. **Check the architecture** in [ARCHITECTURE.md](docs/ARCHITECTURE.md) (which context owns it, data model, API contract).
3. **Implement domain logic first** (pure, testable, framework-agnostic).
4. **Add infrastructure adapters** (HTTP controller, DB repository).
5. **Write integration test** to verify end-to-end.
6. **Update traceability** in ARCHITECTURE §14 if needed.

### Handling a Double-Spend Scenario

1. Merchant 1 uploads coin X → first insert to `spent_coins` succeeds → credit M1.
2. Merchant 2 uploads coin X → unique constraint violation → treat as conflict.
3. Emit `DoubleSpendDetected` event → risk module flags payer → attempt clawback from payer bank account.
4. If clawback fails → write-off amount, blacklist device (FR-SET-05, FR-RSK-05).

### Adding a Server-Configurable Limit

1. Add field to `config` table (e.g., `max_offline_cumulative`).
2. Implement `GET /config` endpoint to fetch server values.
3. Client-side: use fetched values to enforce locally; re-validate at sync.
4. Tests: verify enforcement client-side *and* server-side during settlement.

---

## Honest Limitations & Known Risks

### What We DO NOT Prevent (D3)

- **Device rollback/cloning:** A rooted device can restore a wallet backup and re-spend the same tokens. Mitigation: detect at settlement (spent-coin index) and flag the payer.
- **Device compromise:** Extracted keys allow arbitrary transfers. Mitigation: offline limits cap loss, velocity limits flag anomalies, blacklist on repeat.

### What We DO Detect

- **Double-spend:** unique spent-coin index.
- **Replay:** nonce + merchant binding + freshness window.
- **Tampering:** coin/wallet signatures, HMAC integrity checks.
- **Rollback:** op-counter regression at sync.

### Future Hardening (Not MVP)

- Secure element / hardware-backed monotonic counter (optional bonus; not required for D3).
- Blind signatures (advanced e-cash research; out of scope).
- Zero-knowledge proofs for double-spend attribution (research-grade; not practical for prototype).

---

## Observability & Alerts

**Metrics to track:**
- Issued value, outstanding value, redeemed value (invariant).
- Double-spend count per day.
- Sync failures by error.
- Device blacklist growth.

**Alerts:**
- Money-supply invariant breach.
- Unexpected high double-spend rate.
- New device with failed attestation or root detected.

**Logs:** structured, no secrets. Never log key material or full PII (FR-LED-01, NFR-SEC-08).

---

## References & Related Reading

- **e-cash research:** Chaum (blind signatures), Brands (offline e-cash), GNU Taler, Cashu.
- **CBDC design:** ECB "CBDC Design Choices," BIS offline transaction models, RBI offline digital payments framework.
- **UPI offline:** NPCI UPI Lite / UPI123Pay (real-world offline limits we align with).
- **Protocol:** [PAYMENT_PROTOCOL.md](docs/PAYMENT_PROTOCOL.md) for detailed BLE/QR messaging.

---

## Open Questions & Decisions to Make

- **OQ-1:** Loss-allocation clawback semantics: negative balance vs. write-off only? (Assumed: write-off + flag.)
- **OQ-2:** Exact denomination issuing policy per load amount (FR-ISS-03): confirm coin mix for target spendability.
- **OQ-3:** Merchant-to-customer online refund: include as "Could" or fully defer?
- **OQ-4:** iOS BLE background reception: spike to confirm foreground-only assumption (NFR-CMP-04).

See [REQUIREMENTS.md](docs/REQUIREMENTS.md) §11 for full open question list.

---

## One More Thing

This is a **research-informed, production-inspired prototype**, not production code. The architecture is modeled after real e-cash research and modern offline CBDC design. Every decision is traced back to a requirement. Build with the assumption that future versions will integrate real banking APIs and RBI approval — so keep boundaries clean and avoid prototype-specific hacks.
