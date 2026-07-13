# Architecture — Offline Digital Cash Wallet

**Version 1.0 | Status: Proposal | Last updated: 2026-07-13**

This document defines the complete software architecture for the Offline Digital Cash Wallet prototype. It is derived from [PROJECT_VISION.md](PROJECT_VISION.md) and implements the requirements in [REQUIREMENTS.md](REQUIREMENTS.md). Deep protocol detail lives in [PAYMENT_PROTOCOL.md](PAYMENT_PROTOCOL.md); the threat model lives in [SECURITY.md](SECURITY.md).

Notation: `FR-*` / `NFR-*` refer to requirement IDs; `D1`–`D4` refer to the key design decisions (single-hop, fine-denominations/no-change, software+detect-at-settlement, Android+iOS). No implementation code appears here — schemas and contracts are design artifacts.

---

## 1. Architectural Goals & Principles

| Principle | What it means here |
|-----------|--------------------|
| **Offline-first** | The payment path must work with no server reachable. The server is authoritative only for issuance and settlement, never in the payment loop. |
| **Financial integrity above all** | Every value movement is atomic and double-entry; the money-supply invariant is provable at all times (FR-LED-03). |
| **Security by design** | Signatures verified before value is accepted; keys never leave their trust boundary; honest, documented limits (D3, NFR-SEC-07). |
| **Domain-Driven Design** | The domain (cash, coins, transfers, settlement) is modeled explicitly with bounded contexts and a ubiquitous language shared with the requirements glossary. |
| **Clean / Hexagonal architecture** | Domain logic is independent of frameworks, transport, and storage. Dependencies point inward. |
| **Right-sized for 2 devs** | A modular monolith, not microservices. Complexity is spent on correctness (crypto, ledger), not on operational sprawl. |
| **Testability** | Domain and protocol logic are pure and deterministic where possible, enabling adversarial and property tests (double-spend, replay, invariant). |

---

## 2. System Context (C4 Level 1)

```
                        ┌───────────────────────────┐
                        │   Firebase Authentication │  (identity only)
                        └─────────────┬─────────────┘
                                      │ ID token
   ┌──────────────┐   BLE + QR   ┌────▼───────────┐   HTTPS/JSON   ┌───────────────────┐
   │  Merchant    │◄────────────►│  Mobile App    │◄──────────────►│  Backend           │
   │  (same app,  │  (offline)   │  (Flutter,     │  (online only) │  (Modular Monolith,│
   │  Merchant    │              │  Android+iOS)  │                │  Node.js + TS)     │
   │  Mode)       │              └────────────────┘                └─────────┬─────────┘
   └──────────────┘                                                          │
                                                                   ┌─────────▼─────────┐
                                                                   │   PostgreSQL      │
                                                                   │ (system of record)│
                                                                   └───────────────────┘
                                                                   ┌───────────────────┐
                                                                   │  KMS / Secret mgr │  (issuer key)
                                                                   └───────────────────┘
```

- **Two roles, one app** — a user is a Customer and, in Merchant Mode, a Merchant (FR-MER-01).
- **Firebase** does identity only; the backend independently verifies ID tokens (A4, FR-ID-01).
- **The backend is authoritative** for issuance and settlement, and is the system of record (the ledger). It is **never** in the offline payment path.
- **The bank is simulated inside the backend** (A3) — no external banking APIs.

---

## 3. Container View (C4 Level 2)

| Container | Tech | Responsibility |
|-----------|------|----------------|
| **Mobile App** | Flutter (Dart), Android + iOS (D4) | Wallet UI, offline-first local store, offline payment protocol (BLE/QR), sync client, keystore integration. |
| **Backend API** | Node.js + TypeScript + Express | Auth exchange, device registration, issuance/load, sync, settlement, reconciliation, risk. Modular monolith. |
| **PostgreSQL** | PostgreSQL 15+ | Accounts, coins, transfers, spent-coin index, append-only ledger, risk flags. |
| **KMS / Secret manager** | Cloud KMS/HSM (prod), encrypted local secret (dev) | Custody of the Bank Issuer signing key; rotation. |
| **Job runner** | In-process scheduler (prototype) | Reconciliation, expiry sweeps, risk aggregation. |

**Why TypeScript over plain JS (recommendation):** a value-bearing ledger benefits enormously from compile-time types on money, coin states, and DTOs. It is a low-cost upgrade to the vision's "Node.js + Express" and strongly recommended for correctness. If the team prefers plain JS, enforce runtime schema validation (e.g. Zod) at all boundaries instead.

---

## 4. Domain Model & Bounded Contexts (DDD)

The system is decomposed into seven bounded contexts. In the modular monolith each is a top-level backend module with an explicit public interface; contexts communicate via domain events and well-defined calls, never by reaching into each other's tables.

```
┌─────────────────────────────────────────────────────────────────────┐
│                          BACKEND MODULES                              │
│                                                                       │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────────┐  │
│  │ Identity & │  │ Issuance   │  │ Wallet     │  │ Payment /      │  │
│  │ Device     │  │ (Mint)     │  │ (shadow)   │  │ Transfer       │  │
│  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘  └───────┬────────┘  │
│        │               │               │                 │           │
│  ┌─────▼───────────────▼───────────────▼─────────────────▼────────┐  │
│  │                    Settlement (Redemption)                      │  │
│  └────────────────────────────┬────────────────────────────────── ┘  │
│                                │ emits events                         │
│  ┌─────────────────────────────▼───────────────┐  ┌───────────────┐  │
│  │              Ledger (append-only)            │  │ Risk &        │  │
│  │      + Reconciliation / money-supply         │◄─┤ Compliance    │  │
│  └──────────────────────────────────────────────┘  └───────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.1 Contexts, aggregates & responsibilities

| Context | Aggregate root(s) | Owns | Key rules |
|---------|-------------------|------|-----------|
| **Identity & Device** | `Account`, `Device` | user accounts, device bindings, attestation | One active device per account (FR-ID-04); verify Firebase token → session (FR-ID-01). |
| **Issuance (Mint)** | `IssuanceOrder` | minting coins from bank funds, denomination policy | Atomic debit + mint + ledger entry (FR-ISS-02); embeds issuer `key_id` (NFR-CRY-02); sets expiry (FR-ISS-05). |
| **Wallet (server shadow)** | `WalletShadow` | last-known synced wallet state, op-counter, offline allowance | Rollback tripwire via op-counter (FR-WAL-04, FR-SYNC-05); offline allowance accounting (FR-RSK). |
| **Payment / Transfer** | `Transfer` | verification of owner-signed transfers uploaded at settlement | Validates signatures, nonce, freshness (FR-PAY-04/05); single-hop enforcement (D1). |
| **Settlement (Redemption)** | `Redemption`, `SpentCoin` | exactly-once redemption, double-spend detection, merchant credit | Unique `coin_id` index (FR-SET-03); first-valid-wins (FR-SET-05); serializable conflict resolution (FR-SET-07). |
| **Ledger** | `LedgerEntry` (append-only stream) | immutable double-entry event log, money-supply invariant | Never mutated; source of truth (FR-LED-01/02/03). |
| **Risk & Compliance** | `RiskFlag`, `DeviceBlacklist` | fraud flags, blacklist, velocity/limits config | Flags on double-spend (FR-RSK-05); server-configurable limits (FR-RSK-07). |

### 4.2 Core value objects (ubiquitous language)

- **Money** — integer **paise** (never floats), plus currency = INR (NFR-LEG-03). All amounts stored and computed in paise to avoid rounding error.
- **Denomination** — one of {1, 2, 5, 10, 20, 50, 100, 200, 500} INR (D2).
- **CoinId** — opaque unique identifier (UUID/ULID). Not sequential (avoid enumeration).
- **Signature** — Ed25519 signature + `key_id` (NFR-CRY-01/02).
- **Nonce** — single-use challenge minted by the merchant (FR-PAY-01).
- **Transfer** — `{coin_ids, amount, merchant_id, nonce, timestamp, payer_device_pubkey, payer_signature}` (FR-PAY-04).

### 4.3 Coin lifecycle (state machine)

```
        mint (Issuance)                 offline transfer            upload+verify (Settlement)
  ─────────────────────►  in_customer_wallet ────────────► in_transit ────────────► redeemed
        [issued]              │      ▲                          │
                              │      │ sync (retained)          │ conflict (already redeemed)
                              │      └──────────────────────────┘        │
                     expiry sweep │                                       ▼
                              ▼                                     rejected → clawback → written_off
                          expired ──(auto-refund on sync, FR-SYNC-06)──► voided
```

Coins are **immutable** once minted; only their **status** transitions (tracked server-side; the device tracks its local view). `in_transit` covers the window between an offline transfer and the merchant's settlement — a bucket the money-supply invariant must account for (FR-LED-03).

---

## 5. Backend Architecture

### 5.1 Style: Modular Monolith, Hexagonal layering

A single deployable process with hard internal module boundaries. Each module follows ports-and-adapters:

```
   ┌──────────────────────────────────────────────────────────┐
   │ Interface / Adapters (inbound)                            │
   │  • HTTP controllers (Express routes)  • Job triggers      │
   ├──────────────────────────────────────────────────────────┤
   │ Application layer (use cases / orchestration)             │
   │  • LoadWallet  • RedeemBatch  • RegisterDevice  • Sync    │
   │  • enforces transactions, idempotency, authz              │
   ├──────────────────────────────────────────────────────────┤
   │ Domain layer (pure, framework-free)                       │
   │  • Aggregates, value objects, domain services             │
   │  • Coin lifecycle, invariant math, signature verify rules │
   ├──────────────────────────────────────────────────────────┤
   │ Infrastructure / Adapters (outbound)                      │
   │  • PostgreSQL repositories  • KMS/crypto  • Firebase admin│
   │  • Outbox dispatcher  • Clock                             │
   └──────────────────────────────────────────────────────────┘
```

**Dependency rule:** Interface → Application → Domain; Infrastructure implements ports defined by the Domain/Application. The Domain depends on nothing external — making crypto, invariant, and lifecycle logic unit-testable without a DB.

**Suggested module layout (illustrative, not code):**
```
backend/src/
  modules/
    identity/      { domain, application, infra, http }
    issuance/
    wallet/
    payment/
    settlement/
    ledger/
    risk/
  shared/          { money, crypto ports, result types, errors, clock }
  platform/        { db, config, firebase, kms, http server, outbox }
```

### 5.2 Data model (PostgreSQL)

Conceptual schema (types simplified; amounts in paise). The **ledger is append-only**; state tables are the operational projection and are reconciled against the ledger.

| Table | Key columns | Constraints / notes |
|-------|-------------|---------------------|
| `accounts` | `id`, `firebase_uid` (unique), `bank_balance`, `settlement_balance`, `created_at` | One row per user; both customer & merchant balances. |
| `devices` | `id`, `account_id`, `public_key`, `attestation`, `status`, `op_counter_seen`, `active` | Partial unique index: one `active=true` per `account_id` (FR-ID-04). |
| `coins` | `coin_id` (PK), `denomination`, `issuer_key_id`, `signature`, `owner_account_id`, `status`, `expires_at`, `issued_at` | Status ∈ lifecycle; `denomination` ∈ allowed set (check). |
| `issuance_orders` | `id`, `account_id`, `amount`, `status`, `created_at` | Groups coins minted in one load. |
| `transfers` | `nonce` (PK), `payer_device`, `merchant_account_id`, `amount`, `timestamp`, `payer_signature`, `coin_ids[]` | Uploaded at settlement; `nonce` unique blocks replay (NFR-SEC-06). |
| `spent_coins` | `coin_id` (**UNIQUE**), `redeemed_by`, `transfer_nonce`, `redeemed_at` | **Exactly-once** enforcement (FR-SET-03). The double-spend detector. |
| `ledger_entries` | `seq` (PK, monotonic), `type`, `debit_acct`, `credit_acct`, `amount`, `coin_ref`, `prev_hash`, `hash`, `created_at` | Append-only; hash-chained for tamper evidence (FR-LED-01). |
| `wallet_shadows` | `account_id`, `op_counter`, `offline_spent_window`, `state_hmac`, `last_sync_at` | Rollback + allowance tracking (FR-SYNC-05, FR-RSK-03). |
| `risk_flags` | `id`, `subject_type`, `subject_id`, `reason`, `severity`, `status`, `created_at` | Fraud review queue (FR-RSK-05). |
| `device_blacklist` | `device_id` (PK), `reason`, `created_at` | Refused at register/sync/settle (FR-RSK-04). |
| `outbox` | `id`, `topic`, `payload`, `status`, `created_at`, `dispatched_at` | Reliable async / cross-module events. |
| `idempotency_keys` | `key` (PK), `endpoint`, `response_hash`, `created_at` | Exactly-once for value endpoints. |

### 5.3 Consistency, concurrency & idempotency

- **Atomic value movements** (FR-ISS-02, FR-SET-06, NFR-REL-01): a load and a redemption each execute in a single DB transaction that writes both the state change and the balancing ledger entries.
- **Exactly-once redemption** (FR-SET-03/07): insert into `spent_coins` with the `coin_id` UNIQUE constraint. The first insert wins; a conflicting insert raises a unique violation → treated as double-spend. Run the redemption transaction at **SERIALIZABLE** isolation (or use the unique-constraint conflict directly) so concurrent uploads of the same coin resolve deterministically → **first-valid-wins** (FR-SET-05).
- **Idempotent endpoints**: all value-mutating requests carry an `Idempotency-Key`; replays return the stored response, never re-execute (FR-SYNC-04).
- **Outbox pattern**: domain events (e.g. `DoubleSpendDetected`, `CoinsRedeemed`) are written to `outbox` in the same transaction as the state change, then dispatched asynchronously (to risk, notifications, reconciliation). No lost or double events.

### 5.4 Event-sourced ledger (hybrid)

Full event-sourcing everywhere would over-tax a 2-dev team. The architecture uses a **targeted** approach:

- The **ledger is the event-sourced, append-only source of truth** for value (FR-LED-01). Entries are **hash-chained** (`hash = H(prev_hash || entry)`) for tamper evidence.
- **Operational state tables** (`coins`, `accounts` balances) are a **projection** maintained transactionally alongside ledger writes, and are **reconciled** against the ledger by the reconciliation job (FR-LED-04). Any drift = alert.
- **Money-supply invariant** (FR-LED-03) is computed from the ledger across all buckets:
  `issued = in_customer_wallets + in_transit + in_merchant_wallets_unsettled + redeemed + expired + written_off`.

### 5.5 Cryptography & key management

| Key | Location | Use | Rotation |
|-----|----------|-----|----------|
| **Bank Issuer key** (Ed25519) | KMS/HSM (prod), encrypted secret (dev) — never in app or DB | Signs every coin (FR-ISS-02) | Versioned by `key_id`; coins carry the `key_id`; app bundles a set of trusted issuer public keys (NFR-CRY-02). |
| **Device key** (Ed25519) | Platform keystore, non-exportable | Signs transfers, proves ownership (FR-PAY-04) | New key on device re-registration (FR-ID-04). |
| **Wallet data key** (AES-256) | Derived (HKDF) and wrapped by a keystore key | Encrypts local wallet at rest (NFR-SEC-01) | Rotated on re-key/sync events. |

- The **crypto boundary is a domain port** (`Signer`, `Verifier`, `KeyStore`) with infra adapters (KMS, libsodium). Domain code never touches key bytes.
- **Verification everywhere** (NFR-SEC-03): coin signatures verified at settlement (server) and offline at receipt (merchant device, using bundled issuer public keys).

### 5.6 API surface (contracts, not code)

All endpoints require a backend session (from Firebase ID token exchange) and are HTTPS/JSON. Value endpoints are idempotent.

| Endpoint | Purpose | Notes / requirements |
|----------|---------|----------------------|
| `POST /v1/auth/session` | Exchange Firebase ID token → backend session | FR-ID-01 |
| `POST /v1/devices/register` | Register device public key + attestation | FR-ID-02/03/05; deactivates prior device (FR-ID-04) |
| `POST /v1/wallet/load` | Debit bank account, mint coins, return signed coins | Atomic (FR-ISS-02); idempotent; enforces holding cap (FR-ISS-06) |
| `POST /v1/wallet/sync` | Push op-counter + logs; pull coin statuses, config, allowance reset | Idempotent, resumable (FR-SYNC-*); rollback detection (FR-SYNC-05) |
| `POST /v1/settlement/redeem` | Merchant uploads transfers + coins for settlement | Exactly-once (FR-SET-03); per-coin result on partial failure (FR-SET-08) |
| `GET /v1/config` | Fetch server-driven limits/expiry | FR-RSK-07 |
| `GET /v1/history` | Reconciled transaction history | FR-HIS-03 |
| `POST /v1/refunds` *(Could)* | Merchant → customer bank-account refund (online) | Out-of-scope offline refunds (§9 of REQUIREMENTS) |
| internal `/ops/reconciliation` | Trigger/report invariant checks | FR-LED-04 |

---

## 6. Mobile (Flutter) Architecture

### 6.1 Style: Feature-first Clean Architecture, offline-first

```
mobile/lib/
  core/            crypto ports, result types, money, errors, clock, config
  platform/        keystore (platform channel), ble, qr scanner, connectivity
  data/            local encrypted DB (Drift+SQLCipher), repositories, sync engine, api client
  domain/          entities (Coin, Transfer, Wallet), use cases, repository interfaces
  features/
    auth/          { presentation, application }
    wallet/        { load, balance }
    pay/           { scan, send — payer role }
    receive/       { merchant mode, QR, accept — merchant role }
    history/
  app/             routing, DI, theming, localization (INR/en, hi optional)
```

Layer rule mirrors the backend: **presentation → application (use cases) → domain**, with `data`/`platform` implementing domain-defined interfaces. The **domain is pure Dart** (no Flutter, no plugins) so protocol/crypto/coin logic is unit-testable.

### 6.2 Local persistence & wallet integrity

- **Encrypted local DB**: Drift over **SQLCipher** (or an AES-256-GCM encrypted store); the data key is wrapped by a keystore key (NFR-SEC-01, FR-WAL-03).
- **Wallet state carries an HMAC + monotonic op-counter** (FR-WAL-04): every mutation bumps the counter and re-computes the integrity tag. On load, integrity is verified before any transaction (NFR-SEC-04); a mismatch or counter regression blocks spending and forces a sync.
- **Offline allowance** (per-tx, cumulative, velocity — FR-RSK-01/02) is enforced locally and re-validated server-side at sync; the app never lets a signed transfer exceed the remaining allowance (FR-PAY-10).

### 6.3 State management & platform integration

- **State management**: recommend **Riverpod** (compile-safe DI + testable providers) — Bloc is an acceptable alternative if the team prefers explicit event/state modeling.
- **Platform channels**: keystore key gen/sign (`Android Keystore` / `iOS Keychain+Secure Enclave`, hardware-backed where available — FR-ID-02, NFR-CMP-02); BLE via `flutter_blue_plus`; QR via `mobile_scanner`.
- **iOS BLE background constraints** (NFR-CMP-04, OQ-4): the merchant-receive flow assumes the app is foregrounded during a payment; background reception is out of scope for the prototype.

### 6.4 Denomination selection & no-change (D2)

A local **coin-selection service** (domain) computes an exact-sum subset of held coins for the requested amount (bounded subset-sum / greedy-with-backtracking over the small denomination set). If no exact subset exists, the payment is blocked with guidance (FR-PAY-03) — merchants never give change.

---

## 7. Offline Payment Protocol Architecture

Full wire spec → [PAYMENT_PROTOCOL.md](PAYMENT_PROTOCOL.md). Architectural summary:

**Two-phase, atomic exchange** (FR-PAY-06) over an app-layer authenticated channel (BLE link security is never trusted alone — NFR-SEC-05):

```
Merchant (offline)                          Payer (offline)
   │  1. Show QR {merchant_id, nonce, ts, amount?}
   │◄───────────────── scan ─────────────────┤
   │                                          │ 2. select coins (exact sum, D2)
   │                                          │ 3. sign Transfer{coins,amt,merchant,nonce,ts}
   │◄──── BLE: Transfer + coins ──────────────┤   (PHASE 1: offer)
   │ 4. verify: issuer sigs, not expired,     │
   │    payer sig, nonce==mine & unused,      │
   │    ts fresh (±skew)                      │
   │ 5. persist as redemption proof;          │
   │    mark nonce consumed                    │
   ├──── BLE: signed ACK(nonce) ─────────────►│   (PHASE 2: commit)
   │                                          │ 6. on valid ACK → delete coins
   │                                          │    (no ACK → retain, abort)
```

- **Atomicity**: the payer deletes coins **only** after a valid signed ACK; without it, coins are retained (money never vaporizes). Both sides **dedup by `nonce`** so a retried exchange after a dropped link cannot double-receive or double-delete (FR-PAY-07).
- **Anti-replay**: `nonce` is single-use and merchant-persisted; the Transfer binds `merchant_id` + `nonce` + `timestamp`, so a captured transcript cannot be replayed to a second merchant (NFR-SEC-06). Freshness tolerates bounded clock skew (FR-PAY-08).
- **Single-hop (D1)**: received coins are marked "held for settlement" and are **not** re-spendable offline (FR-PAY-09).
- **QR-only fallback** (FR-PAY-11): if BLE fails, a compact transfer message can be exchanged via displayed/scanned QR, subject to size limits.

---

## 8. Synchronization Architecture

```
Device outbox ──(on connectivity)──► POST /wallet/sync ──► Server
   │  pending redemptions, logs, op-counter, state_hmac
   │◄── coin status updates, allowance reset, config, expiry refunds ──┘
```

- **Idempotent & resumable** (FR-SYNC-04): each sync item carries a stable id; re-sending is safe. Server uses `idempotency_keys` + `outbox`.
- **Rollback detection** (FR-SYNC-05): server compares the device's reported `op_counter` against `wallet_shadows.op_counter`; a regression or stale `state_hmac` → risk flag / possible blacklist.
- **Expiry reconciliation** (FR-SYNC-06): coins past `expires_at` are voided and auto-refunded to the bank account, recorded in the ledger.
- **Allowance reset** (FR-RSK-03): a successful sync refreshes the offline allowance window.

---

## 9. Settlement & Double-Spend Architecture

```
                 ┌───────────────────────── redeem batch ─────────────────────────┐
Merchant upload ─┤ for each (transfer, coins):                                     │
                 │   verify issuer sig + payer sig + not expired + well-formed      │
                 │   INSERT coin_id INTO spent_coins  ── UNIQUE ──┐                 │
                 │        success → credit merchant, ledger entry │                 │
                 │        conflict → DOUBLE-SPEND:                ▼                 │
                 │            reject this redemption (first-valid-wins, FR-SET-05)  │
                 │            emit DoubleSpendDetected → Risk (flag payer)          │
                 │            attempt clawback from payer bank acct → else write-off│
                 └──────────────────────────────────────────────────────────────── ┘
```

- **First-valid-wins** loss allocation (FR-SET-05): the first merchant to settle a coin keeps it; a later conflicting redemption is rejected. The system attempts a clawback from the payer's linked bank account; if unavailable, the amount is recorded as a fraud **write-off** (OQ-1 default) and the payer is flagged/blacklisted (FR-RSK-05).
- **Partial batch resilience** (FR-SET-08): valid coins settle even if some in the batch conflict; the response reports per-coin outcomes.

---

## 10. Security Architecture

Full threat model → [SECURITY.md](SECURITY.md). Architectural stance:

- **Trust boundaries**: (1) device keystore (keys), (2) encrypted local wallet, (3) app-layer secure channel over BLE, (4) TLS to backend, (5) server + KMS. Value crosses a boundary only with a verified signature.
- **Key hierarchy**: issuer key (server/KMS) → coins; device key (keystore) → transfers; wallet data key (derived, keystore-wrapped) → local storage (§5.5).
- **Device binding + attestation** (FR-ID-03/05): device public key registered server-side; optional platform attestation risk-scored.
- **Honest limitation (D3, NFR-SEC-07)**: a rooted/cloned device can double-spend within limits; the architecture **detects** (spent-coin index) and **bounds** (offline limits) rather than prevents. Hardware-backing (StrongBox/Secure Enclave) raises the bar opportunistically but is not required.
- **Defense-in-depth**: root/jailbreak detection (FR-ID-06), velocity/limits (FR-RSK), rollback tripwire (FR-SYNC-05), device blacklist (FR-RSK-04).

---

## 11. Cross-Cutting Concerns

| Concern | Approach |
|---------|----------|
| **Observability** (NFR-MNT-03) | Structured logs (no secrets — NFR-SEC-08); metrics: issued/outstanding/redeemed value, double-spend count, sync failures, invariant status; alerts on invariant breach. |
| **Configuration** | Server-driven limits/expiry via `/config` (FR-RSK-07); environment config for infra. |
| **Error handling** | Domain uses explicit `Result`/typed errors, not exceptions for expected failures (e.g. `ExactAmountImpossible`, `CoinAlreadySpent`). |
| **Audit logging** (FR-LED-01) | Hash-chained ledger + append-only audit stream. |
| **Time** | `Clock` port injected; freshness windows tolerate skew (FR-PAY-08); no reliance on device wall-clock for authority. |
| **i18n/currency** | INR formatting; English default, Hindi optional (NFR-UX-04, NFR-LEG-03). |

---

## 12. Deployment & Environments

- **Environments**: `dev` (local Docker Compose: API + PostgreSQL + Firebase emulator + local secret for issuer key), `staging`, `prod` (managed PostgreSQL + cloud KMS/HSM for issuer key).
- **Backend packaging**: single container image (modular monolith); horizontal scaling is possible later because the ledger's correctness rests on DB constraints (unique spent-coin index, serializable txns), not on single-process assumptions.
- **Database migrations**: versioned, forward-only migrations checked into the repo; the `spent_coins` unique index and `devices` partial-unique index are migration-critical.
- **Secrets**: issuer key and Firebase admin credentials via the secret manager; never in the repo or app bundle (only issuer **public** keys ship in the app).
- **CI/CD**: lint + typecheck + unit/property tests (crypto, invariant, double-spend, replay) gate merges; mobile build matrix for Android + iOS (NFR-CMP-01).
- **Mobile release**: standard store pipelines; minimum OS targets (e.g. Android 10+/iOS 14+ — NFR-CMP-03) to guarantee keystore + BLE capability.

---

## 13. Key Technology Decisions (ADR summary)

| # | Decision | Rationale | Alternatives rejected |
|---|----------|-----------|-----------------------|
| ADR-1 | **Modular monolith** backend | Right-sized for 2 devs; correctness lives in DB constraints + domain logic, not service mesh | Microservices (operational overhead, distributed-txn complexity) |
| ADR-2 | **TypeScript** on Node/Express | Compile-time safety for money/coin states | Plain JS (needs heavy runtime validation) |
| ADR-3 | **Hybrid event-sourcing** (ledger only) | Auditability + invariant where it matters, without full ES cost | Full event sourcing (over-engineering); CRUD-only (weak audit) |
| ADR-4 | **Money as integer paise** | Eliminates float rounding in a value system | Floating-point/decimal-string amounts |
| ADR-5 | **Riverpod** for Flutter state | Testable, compile-safe DI | setState (unscalable), Bloc (heavier; acceptable) |
| ADR-6 | **SQLCipher/Drift** local store | Encrypted, queryable, migratable | Plain SQLite (unencrypted), flat encrypted file (hard to query) |
| ADR-7 | **Unique `coin_id` index** as the double-spend detector | Simple, correct, DB-enforced exactly-once | App-level checks (race-prone) |
| ADR-8 | **Two-phase transfer + signed ACK** | Atomicity across an unreliable BLE link | Fire-and-forget (value loss/duplication) |

---

## 14. Traceability (architecture ↔ requirements)

| Architecture element | Satisfies |
|----------------------|-----------|
| Modular monolith, hexagonal layering (§5.1, §6.1) | NFR-MNT-01/02 |
| Atomic load/redeem, ledger double-entry (§5.3/5.4) | FR-ISS-02, FR-SET-06, FR-LED-02, NFR-REL-01 |
| Unique spent-coin index + serializable (§5.3, §9) | FR-SET-03/05/07 |
| Money-supply invariant across buckets (§5.4) | FR-LED-03/04 |
| Two-phase transfer + nonce dedup (§7) | FR-PAY-06/07, NFR-REL-02 |
| Nonce/merchant/ts binding + freshness (§7) | NFR-SEC-06, FR-PAY-05/08 |
| Single-hop held-for-settlement (§7, §4.3) | D1, FR-PAY-09 |
| Coin-selection exact-sum, no change (§6.4) | D2, FR-PAY-03 |
| Key hierarchy, KMS, verify-everywhere (§5.5, §10) | NFR-SEC-01/02/03, NFR-CRY-* |
| Device binding, one active device (§4.1, §5.2) | FR-ID-03/04 |
| Rollback tripwire via op-counter (§6.2, §8) | FR-WAL-04, FR-SYNC-05 |
| Offline limits/allowance (§6.2) | FR-RSK-01/02/03 |
| Idempotency + outbox + resumable sync (§5.3, §8) | FR-SYNC-04 |
| Both-platform Flutter, keystore/BLE (§6.3) | D4, NFR-CMP-01/02/04 |

---

## 15. Open Architectural Questions & Risks

- **OA-1** — Clawback semantics on double-spend when the payer's bank balance is insufficient: write-off + blacklist (assumed) vs allow negative balance. Tracks REQUIREMENTS OQ-1.
- **OA-2** — Whether to scale the backend beyond one instance in the prototype (not needed; noted for future — correctness already rests on DB constraints).
- **OA-3** — iOS BLE background reception (OQ-4/NFR-CMP-04): confirm foreground-only assumption via a spike.
- **OA-4** — Denomination issuing policy (FR-ISS-03): the exact coin mix per load amount affects offline exact-payment success rate; needs tuning + simulation.
- **R-1** (High) — Rooted/cloned devices double-spend within limits: mitigated (detect + cap + blacklist), not eliminated (D3).
- **R-2** (Medium) — BLE interoperability across Android/iOS device models: mitigated by QR-only fallback (FR-PAY-11).
- **R-3** (Medium) — Subset-sum coin selection edge cases (no exact set): handled by explicit block + guidance (FR-PAY-03), but affects UX.

---

## 16. Next Steps

1. Detail the wire protocol and message formats in [PAYMENT_PROTOCOL.md](PAYMENT_PROTOCOL.md).
2. Complete the STRIDE threat model in [SECURITY.md](SECURITY.md).
3. Produce the database migration set and API request/response schemas.
4. Break the roadmap ([ROADMAP.md](ROADMAP.md)) into sprints mapped to these modules.

---

*Architecture proposal for review. Changes should preserve the traceability table (§14) and the invariant guarantees (§5.4, §9).*
