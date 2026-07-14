# Payment Protocol — Offline Digital Cash Wallet

**Version 1.0 | Status: Proposal | Last updated: 2026-07-13**

This document is the **wire specification** for the offline peer-to-merchant payment exchange. It defines transports, encodings, message formats, the two-phase state machine, verification rules, and error handling. It refines the architectural summary in [ARCHITECTURE.md](ARCHITECTURE.md) §7 and implements the `FR-PAY-*` requirements in [REQUIREMENTS.md](REQUIREMENTS.md). The threat model lives in [SECURITY.md](SECURITY.md).

Notation: `FR-*` / `NFR-*` are requirement IDs; `D1`–`D4` are the key design decisions. Byte sizes are approximate and assume Ed25519 (32-byte keys, 64-byte signatures) and 16-byte (UUID/ULID) identifiers.

---

## 1. Scope & Goals

The protocol governs a single offline payment: **payer → merchant**, both running the same app, merchant offline at payment time.

| Goal | Requirement |
|------|-------------|
| Cryptographic finality offline (no server in the loop) | FR-PAY, NFR-REL-03 |
| Atomicity: value is never lost or duplicated on a dropped link | FR-PAY-06/07, NFR-REL-02 |
| Anti-replay: a captured transcript cannot be re-spent to another merchant | NFR-SEC-06, FR-PAY-05/08 |
| Application-layer authentication independent of BLE link security | NFR-SEC-05 |
| Exact-amount, no-change assembly from fine denominations | D2, FR-PAY-03 |
| Single-hop: received coins are not offline-re-spendable | D1, FR-PAY-09 |
| QR-only fallback when BLE pairing fails | FR-PAY-11 |

**Non-goals:** multi-hop transfer (D1), on-device coin splitting/minting (D2, FR-PAY-12), payer anonymity (NFR-DAT-01). Settlement (merchant → server) is out of scope here — see [ARCHITECTURE.md](ARCHITECTURE.md) §9.

---

## 2. Transports & Roles

```
  PAYER (customer)                              MERCHANT (merchant mode)
        │                                                │
        │   ── scan ──►  QR (discovery + nonce)          │  displays QR
        │                                                │
        │   ◄════════════ BLE (value transfer) ═════════►│  GATT peripheral
        │                                                │
        └── QR-only fallback: display/scan compact frames ┘  (if BLE fails)
```

- **QR** is used for **discovery + challenge**: the merchant displays it; the payer scans it. It carries no secrets (FR-PAY-01).
- **BLE** is used for the **value transfer**. The **merchant is the GATT peripheral** (advertises the service); the **payer is the GATT central** (scans and connects). This matches "merchant shows a QR, customer pays."
- **QR-only fallback** replaces BLE with a sequence of displayed/scanned QR frames when BLE pairing fails (FR-PAY-11).

---

## 3. Encoding

| Path | Encoding | Rationale |
|------|----------|-----------|
| **BLE** | **JSON (UTF-8)**, one object per message, `\n`-framed within a chunked stream | Ample bandwidth; human-readable for debugging; simple in Dart/TS. |
| **QR discovery** | **JSON → base64url**, compact keys | Small payload (no signatures); fits easily. |
| **QR-only fallback frames** | **CBOR → DEFLATE → base45** | CBOR is compact binary; DEFLATE squeezes repeated structure; base45 maps to the efficient QR alphanumeric mode (as in the EU DCC). Needed because a full transfer with signatures is large (§8). |

**Canonical bytes for signing (both paths).** Signatures are computed over a **deterministic byte serialization**, never over the transport-formatted text. The canonical form is the message's signed fields concatenated as length-prefixed CBOR in the field order defined per message below. This makes signature verification independent of JSON key ordering / whitespace / base45 framing.

> Rule: **sign the canonical bytes, transmit in the path encoding.** A verifier reconstructs the canonical bytes from received fields and checks the signature against them.

---

## 4. Core Data Structures

All amounts are integer **paise** (₹1 = 100 paise). Timestamps are RFC 3339 UTC strings on the JSON path and Unix epoch seconds (integer) in canonical/CBOR form.

### 4.1 Coin (as transmitted)

A coin is immutable once minted; only its status changes (tracked locally). Transmitted fields — everything the merchant needs to verify offline:

```jsonc
{
  "coin_id":      "01J...ULID",     // 16-byte opaque id (not sequential)
  "denom":        10000,            // paise; ∈ {100,200,500,1000,2000,5000,10000,20000,50000}
  "issuer_key_id":"bank-2026-01",   // selects which pinned issuer pubkey verifies this coin
  "issued_at":    1752000000,       // epoch seconds
  "expires_at":   1759776000,       // epoch seconds (default +90d, FR-ISS-05)
  "issuer_sig":   "base64(64B)"     // Ed25519 over CoinSigningPayload
}
```

**CoinSigningPayload** (canonical, signed by the Bank Issuer key):
`CBOR([coin_id, denom, issuer_key_id, issued_at, expires_at])`

Denominations are the fixed set {1,2,5,10,20,50,100,200,500} INR expressed in paise (D2).

### 4.2 Transfer object (payer's ownership-transfer proof)

```jsonc
{
  "v":            1,                // protocol version
  "coin_ids":     ["01J...","01J..."],
  "amount":       20000,            // paise; MUST equal Σ denom of listed coins (D2, no change)
  "merchant_id":  "M-01J...",       // from the QR (FR-PAY-04)
  "nonce":        "base64(16B)",    // single-use challenge from the QR (FR-PAY-01)
  "timestamp":    1752403920,       // epoch seconds, payer's clock
  "payer_pubkey": "base64(32B)",    // payer Device Key public key
  "payer_sig":    "base64(64B)"     // Ed25519 over TransferSigningPayload
}
```

**TransferSigningPayload** (canonical, signed by the payer Device Key — FR-PAY-04):
`CBOR([v, sorted(coin_ids), amount, merchant_id, nonce, timestamp, payer_pubkey])`

`coin_ids` are sorted in the signed payload so ordering cannot be tampered without invalidating the signature. Binding `merchant_id + nonce + timestamp` is what defeats replay to a second merchant (NFR-SEC-06).

### 4.3 Signed ACK (merchant's commit)

```jsonc
{
  "v":            1,
  "nonce":        "base64(16B)",    // echoes the transfer's nonce
  "status":       "accepted",       // "accepted" | "rejected"
  "reason":       null,             // set when rejected (see §7)
  "merchant_pubkey":"base64(32B)",
  "merchant_sig": "base64(64B)"     // Ed25519 over AckSigningPayload
}
```

**AckSigningPayload** (canonical, signed by the merchant Device Key):
`CBOR([v, nonce, status, reason ?? ""])`

The merchant's signature over the ACK proves to the payer that **this** merchant committed to **this** nonce, so the payer can safely delete coins (FR-PAY-06).

---

## 5. QR Payload (Discovery + Challenge)

The merchant generates a fresh QR per payment attempt (FR-PAY-01). Compact JSON, then base64url:

```jsonc
{
  "v":   1,
  "typ": "offer-req",
  "mid": "M-01J...",     // merchant_id
  "n":   "base64(16B)",  // single-use nonce (merchant persists it)
  "ts":  1752403900,     // epoch seconds
  "amt": 20000,          // OPTIONAL requested amount in paise (FR-PAY-01)
  "ble": "A1B2"          // OPTIONAL short BLE advertisement hint / rotating id
}
```

- **No secret material** in the QR (FR-PAY-01). The nonce is a public challenge; its security comes from single-use + merchant-side persistence + binding into the signed Transfer.
- The merchant **persists the nonce as issued** and marks it consumed once a valid transfer arrives, rejecting reuse (FR-PAY-08).
- Typical size: ~120–160 bytes → trivial QR (version 6–8).

---

## 6. BLE Profile & Two-Phase Exchange

### 6.1 GATT service (placeholder UUIDs — finalize before implementation)

| Element | UUID (placeholder) | Properties | Purpose |
|---------|--------------------|-----------|---------|
| Service | `0xODCW` → `6f64_6377-...-0000` | — | Offline Digital Cash Wallet payment service |
| `OFFER` characteristic | `...-0001` | Write (chunked) | Payer → merchant: Transfer + coins |
| `ACK` characteristic | `...-0002` | Read / Notify | Merchant → payer: signed ACK |
| `CTRL` characteristic | `...-0003` | Write / Notify | Abort, chunk-count, resume markers |

**Chunking.** BLE ATT MTU is small (negotiated, often 185–512 bytes). Messages larger than one MTU are split into `CTRL`-announced chunks: `{msg_id, seq, total, bytes}`. The receiver reassembles by `msg_id` and verifies `total`. Reassembly is idempotent — re-sent chunks with a seen `(msg_id, seq)` are ignored.

### 6.2 State machine

```
Merchant (peripheral, offline)                 Payer (central, offline)
   │  0. advertise service; show QR                    │
   │◄──────────────── scan QR ─────────────────────────┤ 1. read {mid,n,ts,amt?}
   │                                                    │ 2. assemble EXACT coin set (D2, §6.3)
   │                                                    │ 3. check offline allowance (FR-PAY-10)
   │                                                    │ 4. build Transfer, sign with Device Key
   │◄═══ write OFFER: Transfer + coins (chunked) ═══════┤   ── PHASE 1: OFFER ──
   │ 5. VERIFY (§6.4). If any check fails → rejected    │
   │ 6. persist Transfer as redemption proof;           │
   │    mark nonce consumed; mark coins                 │
   │    "held_for_settlement" (single-hop, D1)          │
   ├═══ notify ACK{status:accepted, sig} ══════════════►│   ── PHASE 2: COMMIT ──
   │                                                    │ 7. verify merchant_sig over ACK + nonce
   │                                                    │ 8. on valid accepted ACK → DELETE coins,
   │                                                    │    decrement allowance, write receipt
   │                                                    │    (no/invalid ACK → RETAIN coins, abort)
```

**Atomicity (FR-PAY-06).** The single point of no return for the payer is **receipt of a valid signed ACK**. Before that, coins are retained; the payment simply fails and can be retried. The merchant's point of no return is **persisting the redemption proof** (step 6), done before sending the ACK — so a merchant never ACKs a payment it hasn't durably stored.

**Idempotent retry (FR-PAY-07).** Both sides key everything on `nonce`:
- If the payer re-sends OFFER for a nonce the merchant already accepted, the merchant **re-sends the same ACK** (it does not re-persist or double-count).
- If the payer already deleted the coins and a duplicate ACK arrives, it is ignored.
- A dropped link after step 6 but before step 8 is recovered by re-reading `ACK` on reconnect; the merchant retains the proof, the payer retains the coins until it sees the ACK.

### 6.3 Coin selection (exact sum, no change — D2, FR-PAY-03)

The payer's app runs a local coin-selection service over the small denomination set:

1. Compute a subset of held, non-expired coins whose `denom` sums **exactly** to `amount` (bounded subset-sum: greedy-largest-first with backtracking; the 9-value denomination set keeps this fast).
2. If **no exact subset exists**, the payment is **blocked** with guidance (choose a different amount, or load more / different denominations) — merchants never give change (FR-PAY-03, NFR-UX-02).
3. Prefer selections that preserve future spendability (spend larger denominations first; keep a spread of small coins).

### 6.4 Merchant verification (offline, before accepting — FR-PAY-05)

All checks run **on-device, offline**, before persisting or ACKing. Any failure → `rejected` ACK with a reason (§7):

1. **Issuer signature** on every coin verifies against the pinned issuer public key selected by `issuer_key_id` (NFR-CRY-02). Unknown `key_id` → reject.
2. **Not expired:** `now ≤ expires_at` for every coin (FR-ISS-05).
3. **Amount integrity:** `amount == Σ denom(coins)` and `coin_ids` matches the coins sent (D2 — no change, no hidden value).
4. **Payer signature:** `payer_sig` verifies over the reconstructed `TransferSigningPayload` using `payer_pubkey` (FR-PAY-04).
5. **Nonce binding:** `nonce == the one I issued` and **unused** (merchant-persisted set — FR-PAY-08).
6. **Merchant binding:** `merchant_id == mine`.
7. **Freshness:** `|now − timestamp| ≤ clock tolerance` (default transfer valid 120s; ±5 min skew tolerance — FR-PAY-08, A6). 
8. **No duplicate coins within the batch** (a coin id appearing twice in one transfer).

> The merchant cannot check the server-side spent-coin index offline. Double-spend across separate payments is **detected later at settlement** (D3) — see [ARCHITECTURE.md](ARCHITECTURE.md) §9. Offline verification only guarantees the transfer is well-formed, fresh, and intended for this merchant.

---

## 7. Errors & Abort

Rejections are delivered as a **signed** `rejected` ACK (so the payer can trust the rejection came from the merchant and safely retain coins) or, for transport-level failures, an unsigned `CTRL` abort.

| `reason` | Meaning | Payer action |
|----------|---------|--------------|
| `bad_issuer_sig` | A coin's issuer signature failed | Retain coins; do not retry same coins |
| `coin_expired` | A coin is past expiry | Retain; reselect non-expired coins or block |
| `amount_mismatch` | `amount ≠ Σ denom` | Retain; treat as app bug / tamper |
| `bad_payer_sig` | Transfer signature invalid | Retain; retry (likely transient encode error) |
| `nonce_unknown` / `nonce_used` | Nonce not issued by me / already consumed | Retain; rescan a fresh QR |
| `not_fresh` | Outside freshness window | Retain; rescan fresh QR (clock skew) |
| `merchant_mismatch` | `merchant_id` not mine | Retain; rescan correct merchant QR |
| `internal` | Merchant-side persistence failed | Retain; retry |

**Transport aborts** (unsigned, `CTRL`): `link_lost`, `chunk_timeout`, `reassembly_failed`, `user_cancelled`. On any abort **before** a valid accepted ACK, the payer retains coins and the payment is void. No partial value moves.

---

## 8. QR-Only Fallback (FR-PAY-11)

When BLE pairing fails, the same two-phase exchange runs over displayed/scanned QR frames.

- **Encoding:** `CBOR → DEFLATE → base45`, split into numbered frames `{msg_id, seq, total, data}` shown as an animated QR sequence; the scanner reassembles by `msg_id`.
- **Direction:** payer displays OFFER frames → merchant scans; merchant displays ACK frame → payer scans.
- **Size reality (why not JSON here):** a transfer with `N` coins ≈ `140 + 85·N` bytes canonical. For `N=20` that is ~1.8 KB before base45 (~+33%) ≈ ~2.4 KB — near a dense version-40 QR's limit. CBOR+DEFLATE keeps this within a small animated sequence; JSON would not fit. For a single frame, the app **caps** the coin count and otherwise splits across frames or instructs the payer to pay a smaller amount.

**Freshness** windows are widened slightly for the fallback to absorb manual scan latency, but still bounded (FR-PAY-08).

---

## 9. Sequence Summary (happy path)

```
Payer                                   Merchant
  │  scan QR {mid, nonce, ts, amt=₹200}    │  (QR displayed)
  │  select coins: [₹100, ₹100]            │
  │  allowance OK; sign Transfer            │
  │ ──────── OFFER (Transfer+coins) ──────► │
  │                                         │  verify issuer sigs ✓ not expired ✓
  │                                         │  amount=Σdenom ✓ payer sig ✓
  │                                         │  nonce mine & unused ✓ fresh ✓
  │                                         │  persist proof; mark nonce used;
  │                                         │  coins → held_for_settlement (D1)
  │ ◄──────── ACK {accepted, sig} ───────── │
  │  verify merchant sig ✓                  │
  │  DELETE coins; allowance −= ₹200;       │
  │  write local receipt                    │
  │  ── payment complete (offline) ──       │
```

Later, out of band: the merchant reconnects and settles (uploads Transfer + coins); the server's unique spent-coin index credits the merchant and detects any double-spend (FR-SET-*).

---

## 10. Constants (defaults, server-configurable — FR-RSK-07)

| Constant | Default | Requirement |
|----------|---------|-------------|
| Transfer validity | 120 s | FR-PAY-08 |
| Clock skew tolerance | ±5 min | FR-PAY-08, A6 |
| Coin expiry | 90 days | FR-ISS-05 |
| Per-transaction limit | ₹5,000 | FR-RSK-01 |
| Max coins per transfer (BLE) | 64 | protocol/perf (NFR-PERF-02) |
| Max coins per transfer (QR fallback) | 20 | QR size (§8) |
| Denomination set | {1,2,5,10,20,50,100,200,500} INR | D2 |
| Protocol version `v` | 1 | — |

---

## 11. Traceability (protocol ↔ requirements)

| Protocol element | Satisfies |
|------------------|-----------|
| QR payload, single-use nonce, merchant-persisted (§5) | FR-PAY-01, FR-PAY-08, NFR-SEC-06 |
| BLE central/peripheral, chunking (§6.1) | FR-PAY-02, NFR-CMP-02 |
| Two-phase OFFER→signed-ACK, delete-after-ACK (§6.2) | FR-PAY-06, NFR-REL-02 |
| Nonce-keyed idempotent retry (§6.2) | FR-PAY-07 |
| Exact-sum coin selection, no change (§6.3) | D2, FR-PAY-03, NFR-UX-02 |
| Offline verification of issuer + payer sigs, expiry, freshness (§6.4) | FR-PAY-05, NFR-SEC-03, NFR-CRY-02 |
| Allowance check before signing (§6.2 step 3) | FR-PAY-10, FR-RSK-01/02 |
| Held-for-settlement, no offline re-spend (§6.2 step 6) | D1, FR-PAY-09 |
| Canonical-bytes signing, app-layer auth over BLE (§3, §4) | NFR-SEC-05, NFR-CRY-01 |
| Signed rejection / transport abort, no partial value (§7) | NFR-REL-01/02 |
| QR-only fallback (§8) | FR-PAY-11 |

---

*Wire specification for review. Any change to a `*SigningPayload` layout is a breaking protocol change and MUST bump `v`. Keep this document in sync with [ARCHITECTURE.md](ARCHITECTURE.md) §7 and the settlement design in §9.*
