# TODO — Offline Digital Cash Wallet

**Last updated: 2026-07-13**

Outstanding tasks and decisions. This is a living document — items should trace to a requirement (`FR-*`/`NFR-*`), a phase in [ROADMAP.md](ROADMAP.md), or an open question. Design docs (Phase 0) are complete; the next work is the first code (Phase 1) plus a few design artifacts still owed.

**Legend:** `[FR-*]` requirement · `(P1)` roadmap phase · `#OQ` open question.

---

## High Priority — Unblock Phase 1

- [ ] Produce the **DB migration set** — `accounts`, `devices` (with one-active-device partial-unique index), `coins`, `ledger_entries`, `spent_coins` (UNIQUE `coin_id`). `[FR-ID-04, FR-SET-03]` (ARCHITECTURE §5.2)
- [ ] Write the **API request/response schemas** for `/auth/session`, `/devices/register`, `/wallet/load` (ARCHITECTURE §5.6, §16). Consider Zod/TS types shared across boundaries.
- [ ] Scaffold **backend** modular monolith (Express + TS, `modules/`+`shared/`+`platform/`). `(P1)`
- [ ] Scaffold **mobile** Flutter app (feature-first clean architecture, Android 10+/iOS 14+). `(P1)`
- [ ] Stand up **dev environment**: Docker Compose (API + PostgreSQL + Firebase emulator + local issuer secret). `(P1)`
- [ ] Implement **crypto ports + libsodium adapter**; sign/verify a coin end-to-end. `[NFR-CRY-01/02]` `(P1)`
- [ ] Implement **device key generation** in platform keystore + `POST /devices/register`. `[FR-ID-02/03]` `(P1)`
- [ ] Set up **CI** (lint + typecheck + unit tests; Android + iOS build matrix). `(P1)`

---

## Medium Priority — Phase 2–4 Groundwork

- [ ] Design the **denomination composition algorithm** and validate the issued mix via simulation. `[FR-ISS-03]` `#OQ-2`
- [ ] Finalize **BLE GATT UUIDs** (service + OFFER/ACK/CTRL characteristics) — currently placeholders. (PAYMENT_PROTOCOL §6.1)
- [ ] Implement the shared **Transfer verification** library (reused offline + at settlement). `[FR-PAY-05, FR-SET-02]`
- [ ] Build the **exact-sum coin selection** service + "impossible amount" UX. `[FR-PAY-03, NFR-UX-02]`
- [ ] Implement the **append-only hash-chained ledger** + double-entry load events. `[FR-LED-01/02]`
- [ ] Implement **`spent_coins` unique-index settlement** + double-spend handling. `[FR-SET-03/04/05]`
- [ ] Implement **idempotent, resumable sync** (outbox model) + rollback detection via op-counter. `[FR-SYNC-04/05]`
- [ ] Implement the **money-supply invariant** check + scheduled reconciliation with alerts. `[FR-LED-03/04]`

---

## Low Priority — Should/Could & Polish

- [ ] **QR-only fallback** exchange (CBOR→DEFLATE→base45 frames). `[FR-PAY-11]` (PAYMENT_PROTOCOL §8)
- [ ] **Attestation** ingest (Play Integrity / App Attest), risk-scored. `[FR-ID-05]`
- [ ] **Root/jailbreak detection** tripwire → risk flag. `[FR-ID-06]`
- [ ] **Per-transaction risk scoring** surfaced to Risk/Ops. `[FR-RSK-06]`
- [ ] **Server-configurable limits** via `GET /config`. `[FR-RSK-07]`
- [ ] **Reconciled history** view with discrepancy marking. `[FR-HIS-03]`
- [ ] **Advanced/diagnostic** per-denomination wallet view. `[FR-WAL-05]`
- [ ] **Localization** (INR/English default, Hindi optional) + accessibility pass. `[NFR-UX-04]`
- [ ] **Observability**: structured logs + metrics (issued/outstanding/redeemed, double-spend count, sync failures). `[NFR-MNT-03]`
- [ ] **Prototype disclaimers** in-app (no real money, simulated bank). `[NFR-LEG-01]`

---

## Open Questions & Decisions Needed

Tracked from [REQUIREMENTS.md](REQUIREMENTS.md) §11 and [ARCHITECTURE.md](ARCHITECTURE.md) §15. Resolve before the dependent phase.

- [ ] **#OQ-1** — Clawback on double-spend when payer balance is insufficient: go negative vs. write-off only? *(Assumed: write-off + flag.)* Needed by `(P4)`. `[FR-SET-05]`
- [ ] **#OQ-2** — Exact denomination issuing policy / target coin mix per load. Needed by `(P2/P3)`. `[FR-ISS-03]`
- [ ] **#OQ-3** — Merchant→customer online refund: include as "Could" this release or fully defer? `[out-of-scope §9]`
- [ ] **#OQ-4** — iOS BLE background reception limits: run a spike; confirm foreground-only merchant-receive assumption. Needed by `(P3)`. `[NFR-CMP-04]`
- [ ] **#OA-2** — Scale backend beyond one instance in the prototype? *(Assumed: no; correctness rests on DB constraints.)*
- [ ] Confirm **team split** (backend/mobile ownership vs. full-stack) to assign roadmap tasks — deferred by request.

---

## De-risking Spikes (Do Early)

- [ ] **BLE interop spike** across representative Android + iOS models (chunking, MTU, reliability). `#R-2`
- [ ] **iOS BLE background** spike. `#OQ-4`
- [ ] **Subset-sum edge cases** for coin selection (no exact set) — measure failure rate vs. issuing policy. `#R-3`

---

## Completed

- [x] Project vision finalized — [PROJECT_VISION.md](PROJECT_VISION.md)
- [x] Requirements (SRS) baselined — [REQUIREMENTS.md](REQUIREMENTS.md)
- [x] Architecture proposal — [ARCHITECTURE.md](ARCHITECTURE.md)
- [x] Payment protocol wire spec — [PAYMENT_PROTOCOL.md](PAYMENT_PROTOCOL.md)
- [x] Security / STRIDE threat model — [SECURITY.md](SECURITY.md)
- [x] Roadmap (phase-based) — [ROADMAP.md](ROADMAP.md)
- [x] CLAUDE.md guidance for future sessions
