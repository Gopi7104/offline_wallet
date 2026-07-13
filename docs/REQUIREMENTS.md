# Requirements — Offline Digital Cash Wallet

**Version 1.0 | Status: Baseline | Last updated: 2026-07-13**

This document is a Software Requirements Specification (SRS) for the Offline Digital Cash Wallet prototype. It defines functional and non-functional requirements, constraints, data and interface requirements, acceptance criteria, and open risks. It is derived from and must be read alongside [PROJECT_VISION.md](PROJECT_VISION.md).

Requirements use stable IDs (`FR-*`, `NFR-*`) and MoSCoW priorities: **Must**, **Should**, **Could**, **Won't (this release)**.

---

## 1. Introduction

### 1.1 Purpose

Enable **small-value digital payments without internet connectivity**, with an ownership-transfer and settlement model that behaves like physical cash. The system is a resilience fallback for connectivity/UPI/bank/network outages — **not** a UPI or bank replacement.

### 1.2 Scope

**In scope (this release):**
- Loading digital cash from a simulated bank account into a device wallet (online).
- Holding cash as Ed25519-signed, fine-denomination tokens (coins) in an encrypted on-device wallet.
- Offline peer-to-merchant payment via QR handshake + BLE transfer of owner-signed coins.
- Server-side settlement, double-spend detection, immutable ledger, and reconciliation.
- Automatic synchronization on reconnect; offline value/velocity limits; risk flagging.
- Simulated bank core (accounts, issuer, settlement engine, ledger, audit, risk).

**Out of scope** — see [§9](#9-out-of-scope).

### 1.3 Key Design Decisions (baked into these requirements)

| # | Decision | Chosen option | Consequence |
|---|----------|---------------|-------------|
| D1 | **Coin circulation** | **Single-hop (redeem-only)** | A merchant CANNOT re-spend received coins offline. Every received coin must be uploaded to the server to settle. Double-spend blast radius = 1 hop. |
| D2 | **Change model** | **Fine denominations, no change** | Wallet holds ₹1/2/5/10/20/50/100/200/500 coins. The payer's app assembles the exact amount from held coins. Merchants never give change. |
| D3 | **Offline security target** | **Software + detect-at-settlement** | Ed25519 + AES-256 in software with keystore-backed keys. Double-spend/cloning is *detected* server-side, not *prevented* on-device. Hardware-backing is a fallback bonus, not a requirement. |
| D4 | **Platform** | **Android and iOS** | Single Flutter codebase targeting both; BLE, secure storage, and permissions implemented for both platforms. |

### 1.4 Definitions & Glossary

- **Coin / Token** — a discrete unit of digital cash of a fixed denomination, signed by the Bank Issuer key. Immutable once minted.
- **Denomination** — face value of a coin, from the fixed set {1, 2, 5, 10, 20, 50, 100, 200, 500} INR.
- **Bank Issuer Key** — server-held Ed25519 keypair that signs coins. The public key is embedded in the app for offline verification.
- **Device Key** — a per-device, non-exportable Ed25519 keypair in the platform keystore, used to sign transfers (proves current ownership).
- **Transfer object** — an owner-signed record binding `{coin_ids, amount, merchant_id, nonce, timestamp}`. It is the merchant's redemption proof.
- **Single-hop** — a coin moves customer → merchant → server (settlement). It does not circulate merchant → merchant offline.
- **Settlement / Redemption** — server verification of uploaded coins + transfers, marking coins spent and crediting the merchant.
- **Spent-coin index** — a server-side unique index over `coin_id` guaranteeing exactly-once redemption.
- **Double-spend** — the same coin transferred/redeemed more than once. Detected at settlement (D3).
- **Offline allowance** — the remaining cumulative value/velocity a device may spend before it must reconnect.
- **PPI** — Prepaid Payment Instrument (RBI-regulated category this concept would fall under in production).

### 1.5 References

- Chaum (1983) blind signatures; Brands (1995) offline e-cash; ECB/BIS offline CBDC design notes; RBI offline digital payments framework; NPCI UPI Lite / UPI123Pay; GNU Taler; Cashu. (Full citations in [PROJECT_VISION.md](PROJECT_VISION.md) appendix.)

---

## 2. Actors & Roles

| Actor | Description |
|-------|-------------|
| **Customer** | Authenticated user who loads and spends digital cash. |
| **Merchant** | Any user in Merchant Mode who receives payments. No separate registration (symmetric role). |
| **Bank Core (simulated)** | Backend that holds accounts, mints coins, settles, and maintains the ledger. |
| **Risk/Ops (internal)** | Operators who review fraud flags and reconciliation reports. |
| **Attacker** (threat actor) | Rooted/cloned device operator attempting double-spend, replay, or tampering. |

---

## 3. System Context & Assumptions

- **A1** — Loading cash requires internet + authentication; only *spending* is offline. This is acceptable and mirrors ATM withdrawal.
- **A2** — Both parties run the app; the merchant is offline at payment time and may reconnect later.
- **A3** — The bank is simulated; no real money moves and no real banking APIs are called.
- **A4** — Firebase provides identity; the backend independently verifies Firebase ID tokens.
- **A5** — Loss of a device = loss of the cash on it (like a lost physical wallet), bounded by the offline allowance (FR-RSK). This is an accepted, documented limitation.
- **A6** — Device clocks may drift; the protocol tolerates bounded skew (FR-PAY-08).

---

## 4. Functional Requirements

### 4.1 Identity & Device (FR-ID)

- **FR-ID-01** (Must) — The system Must authenticate users via Firebase Authentication and exchange the Firebase ID token for a backend session.
- **FR-ID-02** (Must) — On first launch after auth, the app Must generate a non-exportable **Device Key** (Ed25519) in the platform keystore (Android Keystore / iOS Keychain; hardware-backed where available).
- **FR-ID-03** (Must) — The app Must register the Device Key's public key with the backend, binding it to the user account (**device binding**).
- **FR-ID-04** (Must) — A user account Must have exactly one active wallet device at a time. Registering a new device Must invalidate the previous device binding and require a fresh load (mitigates clone/rollback via a new device).
- **FR-ID-05** (Should) — On supported platforms, the app Should submit a key/device attestation (Android Play Integrity / Key Attestation; iOS App Attest) at registration; failures are logged and risk-scored (not hard-blocked in the prototype).
- **FR-ID-06** (Should) — The app Should detect rooted/jailbroken environments and raise a warning + risk flag (defense-in-depth, not a hard block).

### 4.2 Wallet & Balance (FR-WAL)

- **FR-WAL-01** (Must) — The wallet Must store cash as individual denominated coins (D2), each carrying its bank signature, denomination, coin ID, and status.
- **FR-WAL-02** (Must) — The UI Must display only the aggregate balance (sum of coin denominations); the coin structure is hidden from the user.
- **FR-WAL-03** (Must) — The wallet Must be persisted encrypted at rest (see NFR-SEC-01) and its integrity verified before every read that precedes a transaction (see NFR-SEC-04).
- **FR-WAL-04** (Must) — The wallet Must maintain a monotonically increasing local operation counter, included in the signed/HMACed wallet state, so the server can detect rollback at next sync (FR-SYNC-05).
- **FR-WAL-05** (Should) — The app Should show a per-denomination breakdown in an "advanced"/diagnostic view for debugging (not on the primary balance screen).

### 4.3 Issuance / Load (FR-ISS)

- **FR-ISS-01** (Must) — A customer Must be able to load a chosen INR amount from their simulated bank account into the wallet while online.
- **FR-ISS-02** (Must) — On load, the backend Must atomically: debit the customer bank account, mint the corresponding coins as a denomination breakdown of the amount, sign each coin with the Bank Issuer key, and record issuance ledger entries (single DB transaction).
- **FR-ISS-03** (Must) — Coin denomination composition Must be computed to favor spendability (a mix of small and large denominations enabling exact offline amounts), not the minimum coin count.
- **FR-ISS-04** (Must) — Loaded coins Must be delivered to the device over an authenticated channel and stored encrypted.
- **FR-ISS-05** (Must) — Each coin Must carry an **expiry** (default 90 days, configurable). Expired coins are invalid for transfer and are auto-refunded on sync (FR-SYNC-06).
- **FR-ISS-06** (Must) — A load Must be rejected if it would push the wallet above the maximum wallet holding cap (NFR/config; default equal to the cumulative offline cap).
- **FR-ISS-07** (Should) — The system Should support a configurable per-denomination issuing policy so the issued mix can be tuned.

### 4.4 Offline Payment / Transfer (FR-PAY)

- **FR-PAY-01** (Must) — A merchant Must be able to generate a **payment QR** containing `{merchant_id, single-use nonce, timestamp, requested_amount?}`. The QR Must contain no secret material.
- **FR-PAY-02** (Must) — The payer's app Must scan the QR, then establish a BLE connection to the merchant device to exchange payment messages.
- **FR-PAY-03** (Must) — The payer's app Must automatically select a set of held coins whose denominations sum **exactly** to the amount (D2). If no exact set exists, the payment Must be blocked with clear guidance (choose a different amount / load more). Merchants Must NOT give change.
- **FR-PAY-04** (Must) — The payer Must sign a **Transfer object** binding `{coin_ids, amount, merchant_id, nonce, timestamp}` with the Device Key. This signature is the proof of authorized ownership transfer.
- **FR-PAY-05** (Must) — The merchant Must verify **offline**, before accepting: (a) each coin's Bank Issuer signature against the embedded public key; (b) the coin is not expired; (c) the payer's Device signature over the Transfer; (d) the nonce equals the one it issued and is unused; (e) the timestamp is within the freshness window.
- **FR-PAY-06** (Must) — Transfer Must be **atomic** via a two-phase exchange: the payer sends the Transfer + coins; the merchant validates and returns a **signed ACK**; the payer deletes the transferred coins **only** after receiving a valid ACK. Without an ACK, the payer Must retain the coins and the payment aborts.
- **FR-PAY-07** (Must) — Both sides Must deduplicate by Transfer nonce so a retried exchange after a dropped connection cannot cause the merchant to double-receive or the payer to double-delete.
- **FR-PAY-08** (Must) — The freshness window Must tolerate bounded clock skew (default: transfer valid for 120s; ±5 min clock tolerance). The merchant Must persist consumed nonces to reject replays.
- **FR-PAY-09** (Must) — Received coins Must be marked "held for settlement" in the merchant wallet and Must NOT be re-spendable offline (D1 — single-hop).
- **FR-PAY-10** (Must) — Every offline payment Must be checked against and decremented from the device's offline allowance (FR-RSK-01/02) before it is signed.
- **FR-PAY-11** (Should) — The app Should support a fully in-person **QR-only fallback** (display/scan of a compact transfer message) when BLE pairing fails, subject to QR size limits.
- **FR-PAY-12** (Won't) — Splitting/merging coins on-device (offline minting) Will NOT be supported; only the bank mints (D2).

### 4.5 Settlement / Redemption (FR-SET)

- **FR-SET-01** (Must) — When online, a merchant Must upload received Transfers + coins to the backend for settlement, without requiring the payer to be online.
- **FR-SET-02** (Must) — Settlement Must verify: Bank Issuer signature on each coin, payer Device signature on the Transfer, coin not expired, and Transfer well-formed.
- **FR-SET-03** (Must) — Redemption Must be **exactly-once** and **idempotent**: enforced by a unique index on `coin_id` in the spent-coin store. Re-uploading the same Transfer Must NOT credit the merchant twice.
- **FR-SET-04** (Must) — On a coin already recorded as redeemed by a different merchant, the system Must treat it as a **double-spend**: apply the loss-allocation policy (FR-SET-05) and raise a fraud flag against the payer (FR-RSK-05).
- **FR-SET-05** (Must) — **Loss-allocation policy: first valid redemption wins.** The first merchant to successfully settle a coin is credited. A later conflicting redemption is rejected; the system attempts a clawback from the payer's linked bank account, and if unavailable, records the amount as a fraud write-off. This policy Must be surfaced to merchants in-app.
- **FR-SET-06** (Must) — On successful settlement, the backend Must credit the merchant account and transition each coin `in_merchant_wallet → redeemed` within a single DB transaction.
- **FR-SET-07** (Must) — Concurrent redemption attempts for the same coin Must be serialized (serializable isolation / unique-constraint conflict) so exactly one succeeds deterministically.
- **FR-SET-08** (Should) — Settlement Should be resilient to partial batch failure: valid coins settle, invalid/duplicate coins are reported per-coin without failing the whole batch.

### 4.6 Ledger & Reconciliation (FR-LED)

- **FR-LED-01** (Must) — The backend Must maintain an **append-only, immutable ledger** (event-sourced) of every issuance, transfer-observed, redemption, clawback, expiry, and write-off event.
- **FR-LED-02** (Must) — Every value movement Must be recorded as balanced double-entry accounting (e.g., load = debit customer account, credit "digital-cash outstanding" liability).
- **FR-LED-03** (Must) — The system Must enforce/verify the **money-supply invariant** across all buckets: `issued = in_customer_wallets + in_transit(offline, unsettled) + in_merchant_wallets(unsettled) + redeemed + expired + written_off`.
- **FR-LED-04** (Must) — A reconciliation job Must run on a schedule (daily minimum) and alert on any invariant breach.
- **FR-LED-05** (Should) — Coin lifecycle states Must be explicit and auditable: `issued → in_customer_wallet → in_transit → in_merchant_wallet → redeemed`, with side states `expired`, `void`, `clawed_back`, `written_off`.

### 4.7 Risk, Limits & Fraud (FR-RSK)

- **FR-RSK-01** (Must) — The system Must enforce a **per-transaction limit** (default ₹5,000, configurable).
- **FR-RSK-02** (Must) — The system Must enforce a **cumulative offline limit** (default ₹50,000) and a **velocity limit** (default 5 offline payments / 24h rolling). Exceeding either blocks further offline payment until reconnect + sync.
- **FR-RSK-03** (Must) — Offline allowance Must reset/refresh only on a successful server sync.
- **FR-RSK-04** (Must) — The backend Must maintain a **device blacklist**; blacklisted devices are refused at registration/sync/settlement of their coins.
- **FR-RSK-05** (Must) — On detected double-spend, the payer's device/account Must be flagged for review, and repeat offenders Must be auto-blacklisted (threshold configurable).
- **FR-RSK-06** (Should) — The system Should compute a per-transaction risk score (new device, failed attestation, root detected, velocity anomalies) and expose flagged events to Risk/Ops.
- **FR-RSK-07** (Should) — All limits/thresholds Should be server-configurable without an app release.

### 4.8 Synchronization (FR-SYNC)

- **FR-SYNC-01** (Must) — The app Must automatically sync when connectivity is available, without user intervention.
- **FR-SYNC-02** (Must) — Sync Must upload the merchant's pending redemptions and the customer's transaction/audit logs.
- **FR-SYNC-03** (Must) — Sync Must refresh the offline allowance, coin statuses, and any server-driven config (limits, expiry).
- **FR-SYNC-04** (Must) — Sync Must be idempotent and resumable (safe to interrupt and retry); use an outbox/ack model so no event is lost or double-applied.
- **FR-SYNC-05** (Must) — Sync Must send the wallet's signed state + local operation counter; the server Must detect a **rollback** (counter regression / stale state) and flag/blacklist the device.
- **FR-SYNC-06** (Must) — On sync, coins past expiry Must be reconciled and their value auto-refunded to the customer's bank account (recorded in the ledger).

### 4.9 Merchant Mode (FR-MER)

- **FR-MER-01** (Must) — Any authenticated user Must be able to switch into Merchant Mode and obtain a Merchant ID, merchant wallet, and QR generation — with no separate registration.
- **FR-MER-02** (Must) — Merchant Mode Must show received (pending-settlement) and settled amounts distinctly.
- **FR-MER-03** (Should) — Merchant Mode Should show settlement status per payment (pending / settled / rejected-double-spend) after sync.

### 4.10 Transaction History & Receipts (FR-HIS)

- **FR-HIS-01** (Must) — Both roles Must have a local, tamper-evident transaction history (loads, payments sent, payments received, settlements, refunds).
- **FR-HIS-02** (Must) — Each offline payment Must produce a local receipt (amount, counterparty ID, timestamp, transfer nonce) available offline.
- **FR-HIS-03** (Should) — History Should reconcile with server records after sync and mark any discrepancies.

---

## 5. Non-Functional Requirements

### 5.1 Security (NFR-SEC)

- **NFR-SEC-01** (Must) — The wallet Must be encrypted at rest with AES-256-GCM; the data-encryption key Must be wrapped by a keystore-held key (hardware-backed where available).
- **NFR-SEC-02** (Must) — Private keys (Device Key; Bank Issuer Key) Must never leave their trust boundary (keystore / server KMS).
- **NFR-SEC-03** (Must) — All coin and transfer signatures Must be verified before any value is credited or accepted — offline (merchant) and online (settlement).
- **NFR-SEC-04** (Must) — Wallet state Must carry an integrity tag (HMAC or signature) + operation counter; a failed integrity or a counter regression Must block transactions and trigger a sync/flag.
- **NFR-SEC-05** (Must) — Application-layer authentication/encryption Must protect the BLE payment exchange regardless of BLE link-layer security (never trust "Just Works" pairing alone).
- **NFR-SEC-06** (Must) — Replay Must be prevented via single-use merchant nonces + freshness window + merchant-side nonce persistence + settlement re-check.
- **NFR-SEC-07** (Must) — The threat model Must be documented explicitly, including the accepted limitation that a rooted/cloned device can double-spend and is only *detected* (D3), bounded by limits.
- **NFR-SEC-08** (Should) — Secrets/keys Must not be logged; audit logs Must not contain private key material or full PII.

### 5.2 Cryptography (NFR-CRY)

- **NFR-CRY-01** (Must) — Signatures: Ed25519. Symmetric: AES-256-GCM. KDF: HKDF. RNG: platform CSPRNG.
- **NFR-CRY-02** (Must) — The Bank Issuer public key Must be pinned/embedded in the app for offline verification; issuer key rotation Must be supported via key IDs on coins.
- **NFR-CRY-03** (Should) — Crypto Must use well-audited libraries (libsodium / tweetnacl); no custom primitives.

### 5.3 Performance (NFR-PERF)

- **NFR-PERF-01** (Should) — An offline payment (scan → verify → transfer → ACK) Should complete in ≤ 5 seconds under normal BLE conditions.
- **NFR-PERF-02** (Should) — Coin signature verification Should handle a typical transfer (≤ ~20 coins) in ≤ 500 ms on a mid-range device.
- **NFR-PERF-03** (Should) — Settlement of a typical batch Should complete in ≤ 2 seconds server-side.

### 5.4 Reliability & Availability (NFR-REL)

- **NFR-REL-01** (Must) — No single value movement may leave the system in an inconsistent state; loads, transfers, and redemptions are atomic (all-or-nothing).
- **NFR-REL-02** (Must) — Interrupted BLE transfers or syncs Must not lose or duplicate value (FR-PAY-06/07, FR-SYNC-04).
- **NFR-REL-03** (Should) — The offline payment path Must function with the device in airplane mode / no server reachable.

### 5.5 Usability & Accessibility (NFR-UX)

- **NFR-UX-01** (Must) — Users see a simple balance and pay/receive flow; cryptography and coins are hidden.
- **NFR-UX-02** (Must) — When exact-amount assembly is impossible (D2), the app Must clearly explain why and offer next steps.
- **NFR-UX-03** (Should) — The app Should clearly indicate online/offline state and remaining offline allowance.
- **NFR-UX-04** (Should) — Primary flows Should be accessible (readable contrast, screen-reader labels) and localized for INR/English (Hindi optional).

### 5.6 Compatibility / Platform (NFR-CMP)

- **NFR-CMP-01** (Must) — A single Flutter codebase Must target **Android and iOS** (D4).
- **NFR-CMP-02** (Must) — BLE, secure storage, and permission flows Must be implemented and tested on both platforms (Android BLE + Keystore/StrongBox; iOS Core Bluetooth + Keychain/Secure Enclave).
- **NFR-CMP-03** (Should) — Minimum OS targets Should be defined (e.g., Android 10+ / iOS 14+) to ensure keystore + BLE capability.
- **NFR-CMP-04** (Should) — iOS BLE background-mode constraints Should be accounted for in the merchant-receive flow.

### 5.7 Maintainability & Observability (NFR-MNT)

- **NFR-MNT-01** (Must) — Backend Must be a modular monolith with explicit bounded-context modules (Identity, Issuance, Wallet, Payment, Settlement, Ledger, Risk) and clean-architecture layering.
- **NFR-MNT-02** (Must) — Flutter Must use feature-first clean architecture with a dedicated offline-first data/sync layer.
- **NFR-MNT-03** (Should) — The system Should emit structured logs, metrics (issued/outstanding/redeemed value, double-spend count, sync failures), and alerts on invariant breaches.
- **NFR-MNT-04** (Should) — A new developer Should be able to build and run both apps + backend from README in ≤ 1 day.

### 5.8 Data & Privacy (NFR-DAT)

- **NFR-DAT-01** (Must) — The server records issuance and redemption, so transactions are **traceable** (no payer anonymity) — this is an explicit, documented design choice favoring fraud detection over privacy.
- **NFR-DAT-02** (Must) — PII Must be minimized and access-controlled; ledger stores account/device references, not raw sensitive data where avoidable.
- **NFR-DAT-03** (Should) — Data retention and deletion policy Should be defined for logs and closed accounts.

### 5.9 Compliance & Legal (NFR-LEG)

- **NFR-LEG-01** (Must) — The app Must clearly disclaim that it is a **prototype**, handles **no real money**, and simulates the bank.
- **NFR-LEG-02** (Must) — Documentation Must note that a production deployment would fall under RBI **PPI/CBDC regulation** and require licensing/approval (out of scope here).
- **NFR-LEG-03** (Should) — Currency Must be **INR only**; amounts formatted per Indian conventions.

---

## 6. Data Requirements (key entities)

| Entity | Key attributes | Notes |
|--------|----------------|-------|
| **Account** | id, user_ref (Firebase uid), type (customer/merchant), bank_balance, settlement_balance | One user can be both roles. |
| **Device** | id, account_id, device_pubkey, attestation, status (active/blacklisted), op_counter_seen | One active device per account (FR-ID-04). |
| **Coin** | coin_id, denomination, issuer_key_id, bank_signature, expiry, status | Immutable; status drives lifecycle (FR-LED-05). |
| **Transfer** | nonce, payer_device, merchant_id, coin_ids, amount, timestamp, payer_signature, ack | Redemption proof (FR-PAY-04). |
| **LedgerEvent** | seq, type, refs, amounts, prev_hash/signature, created_at | Append-only, immutable (FR-LED-01). |
| **SpentCoin** | coin_id (unique), redeemed_by, transfer_nonce, redeemed_at | Enforces exactly-once (FR-SET-03). |
| **RiskFlag** | id, subject (device/account), reason, severity, status | Fraud/anomaly review (FR-RSK). |

---

## 7. External Interface Requirements

- **API (HTTPS/JSON):** `POST /auth/session`, `POST /devices/register`, `POST /wallet/load`, `POST /wallet/sync`, `POST /settlement/redeem`, `GET /config`, internal `/reconciliation/*`. All authenticated (Firebase session), all value endpoints idempotent.
- **QR:** compact payload `{v, merchant_id, nonce, ts, amount?}`; no secrets; sized within QR capacity.
- **BLE:** GATT service for payment exchange; app-layer authenticated + encrypted messages (NFR-SEC-05); defined message set (offer, transfer+coins, signed-ACK, abort).

---

## 8. Constraints

- **C1** — Prototype; no real banking APIs; no real money movement.
- **C2** — Firebase only for authentication; PostgreSQL is the system of record.
- **C3** — Offline comms limited to QR + BLE (no NFC this release).
- **C4** — Two-developer team; scope must fit ~6–9 months (see [ROADMAP.md](ROADMAP.md)).
- **C5** — INR only.

---

## 9. Out of Scope

- Multi-hop coin circulation (merchant re-spending offline) — excluded by D1.
- On-device coin splitting / offline minting — excluded by D2.
- Payer anonymity / blind signatures — excluded by NFR-DAT-01.
- Offline peer-to-peer **change** and offline refunds — merchant refunds, if any, are **online** to the bank account (Could, future); offline refund is Won't.
- Real bank/UPI integration, KYC, dispute-resolution workflows, interest/fees, NFC, wearables, multi-currency.
- Hardware secure-element requirement (hardware-backing is used opportunistically, not required — D3).

---

## 10. Acceptance Criteria (traceability to Success Criteria)

| # | Criterion | Verified by |
|---|-----------|-------------|
| AC-1 | End-to-end offline payment works: load → offline → QR+BLE transfer → merchant receives → settlement credits merchant with the payer offline. | FR-ISS, FR-PAY, FR-SET |
| AC-2 | Double-spend is detected: two merchants upload the same coin → first wins, second rejected, payer flagged. | FR-SET-03/04/05, FR-RSK-05 |
| AC-3 | Exact-amount payment succeeds via fine denominations; impossible exact amount is blocked with guidance; merchant gives no change. | FR-PAY-03 |
| AC-4 | Money-supply invariant holds across all buckets after a mixed workload. | FR-LED-03/04 |
| AC-5 | Offline limits enforced; blocked after cumulative/velocity cap; reset only after sync. | FR-RSK-01/02/03, FR-SYNC-03 |
| AC-6 | Replay blocked (transfer to a second merchant rejected); tampered coin/wallet rejected; rollback detected at sync. | NFR-SEC-04/06, FR-SYNC-05 |
| AC-7 | Interrupted BLE transfer neither loses nor duplicates value. | FR-PAY-06/07 |
| AC-8 | Runs on both Android and iOS from one codebase. | NFR-CMP-01/02 |

---

## 11. Open Questions & Risks

- **OQ-1** — Loss-allocation clawback (FR-SET-05): in the simulated bank, should a failed clawback debit go negative or write-off only? (Assumed: write-off + flag.)
- **OQ-2** — Exact denomination issuing policy (FR-ISS-03): confirm the target coin mix per load amount.
- **OQ-3** — Merchant-to-bank online refund: include as a "Could" this release or fully defer?
- **OQ-4** — iOS BLE background reception limits may constrain the merchant-offline-receive UX; needs a spike.
- **R-1** (High) — Rooted/cloned devices can double-spend within limits; mitigated by detection + caps + blacklist, not eliminated (accepted, D3).
- **R-2** (Medium) — BLE reliability/interoperability across Android/iOS models; mitigated by QR-only fallback (FR-PAY-11).
- **R-3** (Medium) — Clock skew affecting freshness; mitigated by tolerance window (FR-PAY-08).

---

## 12. Priority Summary (MoSCoW)


- **Must (MVP core):** FR-ID-01..04, FR-WAL-01..04, FR-ISS-01..06, FR-PAY-01..10, FR-SET-01..07, FR-LED-01..04, FR-RSK-01..05, FR-SYNC-01..06, FR-MER-01/02, FR-HIS-01/02; all `NFR-SEC`, `NFR-CRY`, `NFR-REL`, `NFR-CMP-01/02`, `NFR-LEG-01/02`.
- **Should:** attestation/root detection, risk scoring, QR-only fallback, performance targets, observability, accessibility/localization.
- **Could:** online merchant refunds, advanced per-denomination diagnostics, configurable issuing policy tuning.
- **Won't (this release):** multi-hop circulation, on-device coin splitting, anonymity/blind signatures, offline refunds, NFC, multi-currency.

---

*Requirements baseline for review. Changes should be tracked by requirement ID. Next: detailed [ARCHITECTURE.md](ARCHITECTURE.md), [SECURITY.md](SECURITY.md) threat model, [PAYMENT_PROTOCOL.md](PAYMENT_PROTOCOL.md), and sprint breakdown in [ROADMAP.md](ROADMAP.md).*
