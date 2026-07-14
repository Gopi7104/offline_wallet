# Roadmap — Offline Digital Cash Wallet

**Version 1.0 | Status: Proposal | Last updated: 2026-07-13**

Development roadmap for the Offline Digital Cash Wallet prototype (~6–9 months, 2 developers). It expands the phase plan in [PROJECT_VISION.md](PROJECT_VISION.md) §9 and maps each phase to the modules and requirements in [ARCHITECTURE.md](ARCHITECTURE.md) and [REQUIREMENTS.md](REQUIREMENTS.md).

**Structure:** phase-based with explicit goals, parallel Backend/Mobile tracks, cross-cutting work, dependencies, and a **Definition of Done (DoD)**. No fixed calendar dates — phases advance when their DoD is met. Effort weights (S/M/L) are relative sizing hints, not durations.

**Legend:** ✅ done · 🔨 in progress · ⬜ not started · `[L]`/`[M]`/`[S]` relative size.

---

## Status Snapshot

| Phase | Theme | State |
|-------|-------|-------|
| 0 | Design & specification | ✅ Vision, Requirements, Architecture, Protocol, Security drafted |
| 1 | Foundation (crypto, identity, scaffolding) | ⬜ |
| 2 | Core wallet & load | ⬜ |
| 3 | Offline payment protocol | ⬜ |
| 4 | Settlement & ledger | ⬜ |
| 5 | Offline limits & risk | ⬜ |
| 6 | Testing & hardening | ⬜ |

The `backend/` and `mobile/` directories are currently empty — Phase 1 is the first code.

---

## Phase 0 — Design & Specification ✅

**Goal:** a complete, traceable design before code.

- ✅ [PROJECT_VISION.md](PROJECT_VISION.md) — vision, principles, flows.
- ✅ [REQUIREMENTS.md](REQUIREMENTS.md) — SRS with FR/NFR + acceptance criteria.
- ✅ [ARCHITECTURE.md](ARCHITECTURE.md) — modules, data model, API contracts, traceability.
- ✅ [PAYMENT_PROTOCOL.md](PAYMENT_PROTOCOL.md) — wire spec, two-phase exchange.
- ✅ [SECURITY.md](SECURITY.md) — STRIDE threat model, key management.
- ⬜ DB migration set + API request/response schemas (deferred; produced at the start of the phase that first needs them — see [TODO.md](TODO.md)).

**DoD:** design docs cross-reference cleanly; every FR/NFR has an owning module. **Met.**

---

## Phase 1 — Foundation

**Goal:** infrastructure, crypto primitives, identity. Nothing spends yet — but a user can sign in, the backend can sign a coin, and the app can encrypt a wallet.

**Backend**
- `[M]` Express + TypeScript scaffold; modular-monolith layout (`modules/`, `shared/`, `platform/`) per ARCHITECTURE §5.1.
- `[M]` PostgreSQL + migrations tooling; `accounts`, `devices` tables incl. one-active-device partial-unique index (FR-ID-04).
- `[S]` Firebase Admin: verify ID token → backend session (FR-ID-01).
- `[M]` Crypto ports (`Signer`/`Verifier`/`KeyStore`) + libsodium adapter; issuer keypair in local encrypted secret (dev) (NFR-CRY-01/03).
- `[S]` Coin domain model + `CoinSigningPayload`; sign/verify a coin end-to-end (NFR-CRY-02).
- `[S]` `POST /v1/devices/register` (bind device pubkey) (FR-ID-03).

**Mobile**
- `[M]` Flutter scaffold; feature-first clean architecture (ARCHITECTURE §6.1); Android 10+/iOS 14+ targets.
- `[M]` Platform-channel keystore: generate non-exportable Ed25519 device key (Android Keystore / iOS Keychain) (FR-ID-02).
- `[M]` Firebase Auth sign-in → backend session exchange (FR-ID-01).
- `[M]` Encrypted local store (Drift + SQLCipher); AES-256-GCM wallet key wrapped by keystore (NFR-SEC-01).
- `[S]` Bundle issuer public key(s); offline coin-signature verification (NFR-CRY-02).

**Cross-cutting**
- `[S]` CI: lint + typecheck + unit tests; mobile build matrix (Android + iOS).
- `[S]` Dev environment: Docker Compose (API + PostgreSQL + Firebase emulator).

**Dependencies:** none. **DoD:** user signs up; device key generated + registered; backend signs a coin the app verifies offline; app encrypts/decrypts a wallet.

---

## Phase 2 — Core Wallet & Load

**Goal:** load digital cash online; hold it as encrypted, denominated coins.

**Backend**
- `[L]` `POST /v1/wallet/load`: atomic debit → mint denomination breakdown → sign coins → issuance ledger entries, single DB transaction (FR-ISS-01/02).
- `[M]` Denomination composition favoring spendability, configurable policy (FR-ISS-03/07).
- `[M]` Append-only ledger foundation + hash chain; double-entry load events (FR-LED-01/02).
- `[S]` Coin expiry stamping (default 90d) (FR-ISS-05); holding-cap check (FR-ISS-06).
- `[S]` Idempotency keys on value endpoints (FR-SYNC-04).

**Mobile**
- `[M]` Load UI (amount picker, confirmation); aggregate-balance display, coins hidden (FR-WAL-02, NFR-UX-01).
- `[M]` Receive + store signed coins encrypted; verify issuer sigs on receipt (FR-ISS-04, NFR-SEC-03).
- `[M]` Wallet integrity: HMAC tag + monotonic op-counter, verified before reads (FR-WAL-04, NFR-SEC-04).
- `[S]` Sync scaffold (pull coin statuses/config) — full sync in Phase 4.

**DoD (traces AC-1 partial):** load ₹500 → wallet shows 5×₹100 → encrypted at rest → integrity verified on reopen → issuance recorded in ledger.

---

## Phase 3 — Offline Payment Protocol

**Goal:** owner-signed transfers over BLE/QR; merchant receives + verifies offline. The heart of the system.

**Backend**
- `[S]` Merchant Mode enablement: Merchant ID + merchant wallet, no separate registration (FR-MER-01).
- `[S]` Transfer verification library (shared with settlement): payer sig, nonce/merchant binding, freshness (FR-PAY-05).

**Mobile**
- `[M]` Merchant Mode: generate payment QR `{merchant_id, nonce, ts, amount?}`; persist issued/consumed nonces (FR-PAY-01/08).
- `[L]` BLE: merchant peripheral + payer central; GATT service; chunking/reassembly ([PAYMENT_PROTOCOL.md](PAYMENT_PROTOCOL.md) §6.1).
- `[M]` Exact-sum coin selection (subset-sum over denomination set); block + guide if impossible (FR-PAY-03, NFR-UX-02).
- `[M]` Build + sign Transfer (`TransferSigningPayload`) with device key (FR-PAY-04).
- `[L]` Two-phase exchange: OFFER → verify → signed ACK → delete-after-ACK; nonce dedup (FR-PAY-06/07).
- `[M]` Merchant offline verification pipeline (issuer sig, expiry, amount, payer sig, nonce, freshness) (FR-PAY-05).
- `[S]` Mark received coins held-for-settlement, not offline-spendable (D1, FR-PAY-09).
- `[S]` Local receipts both sides (FR-HIS-02); QR-only fallback (FR-PAY-11, Should).

**DoD (traces AC-1, AC-3, AC-7):** Payer scans Merchant QR → BLE → sends ₹200 (2 coins) → merchant verifies offline + ACKs → payer's coins deleted, merchant's wallet shows received; interrupted transfer neither loses nor duplicates value; impossible exact amount is blocked with guidance.

---

## Phase 4 — Settlement & Ledger

**Goal:** server-side settlement, exactly-once redemption, double-spend detection, money-supply invariant.

**Backend**
- `[L]` `POST /v1/settlement/redeem`: verify issuer+payer sigs, insert `spent_coins` (UNIQUE `coin_id`), credit merchant, transition coins → redeemed, in one TX (FR-SET-01/02/03/06).
- `[M]` Double-spend handling: first-valid-wins; conflict → reject + `DoubleSpendDetected` event + clawback attempt/write-off (FR-SET-04/05).
- `[M]` SERIALIZABLE isolation / unique-conflict for concurrent redemption; partial-batch per-coin results (FR-SET-07/08).
- `[L]` `POST /v1/wallet/sync`: idempotent, resumable, outbox model; upload redemptions + logs; pull statuses/config; rollback detection via op-counter (FR-SYNC-01..05).
- `[M]` Money-supply invariant across all buckets + scheduled reconciliation job with alerting (FR-LED-03/04).
- `[S]` Expiry reconciliation + auto-refund on sync (FR-SYNC-06).
- `[S]` `GET /v1/history` reconciled history (FR-HIS-03).

**Mobile**
- `[M]` Auto-sync on reconnect; upload pending merchant redemptions; sync status UI (FR-SYNC-01, FR-MER-03).
- `[S]` Merchant Mode pending vs settled vs rejected display (FR-MER-02/03).

**DoD (traces AC-2, AC-4):** merchant uploads → credited → invariant holds; re-upload rejected; two merchants uploading the same coin → first wins, second rejected, payer flagged.

---

## Phase 5 — Offline Limits & Risk

**Goal:** enforce and reset offline allowance; fraud flagging; device lifecycle.

**Backend**
- `[M]` Per-transaction, cumulative, and velocity limits; server-configurable via `GET /v1/config` (FR-RSK-01/02/07).
- `[M]` Allowance reset only on successful sync; server-side re-validation (FR-RSK-03).
- `[M]` Device blacklist enforced at register/sync/settle; auto-blacklist repeat offenders (FR-RSK-04/05).
- `[S]` Risk scoring (new device, failed attestation, root, velocity anomalies) surfaced to Risk/Ops (FR-RSK-06).
- `[S]` Attestation ingest (Play Integrity / App Attest), risk-scored (FR-ID-05).

**Mobile**
- `[M]` Local offline counter (per-tx + cumulative + velocity); block payment when exceeded (FR-PAY-10, FR-RSK-01/02).
- `[S]` Allowance reset on sync; online/offline + remaining-allowance indicators (NFR-UX-03).
- `[S]` Root/jailbreak detection tripwire → risk flag (FR-ID-06).

**DoD (traces AC-5):** device hits ₹50k cumulative / velocity cap → offline payment blocked → reconnect + sync → allowance resets.

---

## Phase 6 — Testing & Hardening

**Goal:** security review, adversarial + property tests, docs, release readiness.

**Backend**
- `[M]` Unit: coin signing, settlement, invariant math.
- `[M]` Property/adversarial: double-spend, replay, invariant across mixed workloads, concurrent redemption.
- `[S]` Integration: load → transfer → settle; sync idempotency; rollback detection.

**Mobile**
- `[M]` Wallet encryption/integrity tests; transfer signing tests.
- `[M]` BLE protocol tests: replay, tamper, dropped-link atomicity.
- `[S]` End-to-end offline payment on Android + iOS (AC-8).

**Cross-cutting**
- `[M]` Security review against [SECURITY.md](SECURITY.md) STRIDE tables; close/accept each residual risk.
- `[S]` Finalize threat model, API spec, ops runbook; README build-in-≤1-day check (NFR-MNT-04).

**DoD:** coverage >70%; all acceptance criteria (AC-1..8) pass; no critical security findings; docs current.

---

## Milestones

| Milestone | Achieved when |
|-----------|---------------|
| **M1 — Foundations** | Phase 1 DoD: identity + crypto + encrypted wallet |
| **M2 — Money in the wallet** | Phase 2 DoD: online load works end-to-end |
| **M3 — Offline payment works** | Phase 3 DoD: BLE transfer + offline verify (AC-1/3/7) |
| **M4 — Settlement & integrity** | Phase 4 DoD: double-spend detection + invariant (AC-2/4) |
| **M5 — Limits & risk** | Phase 5 DoD: offline limits enforced + reset (AC-5) |
| **M6 — Release-ready prototype** | Phase 6 DoD: tested + hardened (AC-6/8) |

---

## Critical Path & Risks

- **Critical path:** Phase 1 crypto/keystore → Phase 3 protocol → Phase 4 settlement. These carry the correctness-critical work; schedule the most experienced effort here.
- **Parallelism:** Backend and Mobile tracks run in parallel within each phase; the shared **Transfer verification** logic (Phase 3) is the main sync point.
- **R-2 — BLE interop** across Android/iOS models: de-risk early with a Phase 3 spike; QR-only fallback is the safety net (FR-PAY-11).
- **OA-3 — iOS BLE background** (NFR-CMP-04): confirm foreground-only assumption with a spike before committing merchant-receive UX.
- **OA-4 — Denomination policy** (FR-ISS-03): tune coin mix via simulation to maximize exact-amount success before Phase 3 hardening.

---

## Future Considerations (Post-Prototype)

- Hardware secure-element / monotonic counter to *prevent* (not just detect) rollback (raises D3 bar).
- Real bank/UPI integration, KYC, RBI PPI/CBDC licensing pathway (NFR-LEG-02).
- Multi-hop circulation, on-device change, offline refunds (currently out of scope — [REQUIREMENTS.md](REQUIREMENTS.md) §9).
- Backend horizontal scaling (correctness already rests on DB constraints, not single-process assumptions).
- Privacy-preserving variants (blind signatures) if anonymity becomes a goal.

---

*Roadmap for review. Update the Status Snapshot and Milestones as phases complete; keep DoD items traceable to acceptance criteria (AC-1..8) in [REQUIREMENTS.md](REQUIREMENTS.md) §10.*
