# Offline Digital Cash Wallet

A secure mobile payment platform for **small-value transactions when the internet, banking infrastructure, UPI, or cellular networks are unavailable** — rural areas, underground metros, crowded events, disasters, and outages.

It behaves like **physical cash**: ownership transfers immediately via cryptographic proof during an offline payment, and settlement happens later when the merchant reconnects. This is a **resilience fallback**, not a replacement for UPI or banks.

> ⚠️ **Prototype.** No real money moves; the bank is simulated. A production deployment would fall under RBI PPI/CBDC regulation and require licensing.

---

## How it works

```
   Load (online)              Pay (offline)                 Settle (later, online)
 bank ₹ ──► signed      customer ──QR+BLE──► merchant     merchant ──► server
 coins on device        owner-signed transfer             unique spent-coin index
                        of exact-amount coins             credits merchant, detects
                                                          double-spend
```

- **Digital cash, not a balance number** — the wallet holds Ed25519-signed, fine-denomination coins.
- **Owner-signed transfers** — each payment is signed by the payer's device key and bound to `merchant + nonce + timestamp`, so it can't be replayed to another merchant.
- **Detect, don't prevent (honest security)** — software on a consumer phone can't stop a rooted device from cloning/rolling back a wallet; we **detect** double-spends at settlement, **bound** the loss with offline limits, and **attribute** them to the payer.
- **Offline by design** — the server is needed only to load and to settle, never in the payment loop.

## Tech stack

| Layer | Choice |
|-------|--------|
| Mobile | Flutter (Android + iOS) |
| Backend | Node.js + TypeScript + Express (modular monolith) |
| Database | PostgreSQL (append-only ledger + spent-coin index) |
| Auth | Firebase Authentication |
| Offline comms | QR (discovery) + BLE (value transfer) |
| Crypto | Ed25519, AES-256-GCM, HKDF (libsodium / tweetnacl) |

## Repository layout

```
backend/    Node.js + TypeScript API (not yet scaffolded — Phase 1)
mobile/     Flutter app (not yet scaffolded — Phase 1)
docs/       Design & specification (complete)
CLAUDE.md   Guidance for Claude Code sessions
```

## Documentation

Start here, in order:

1. **[docs/PROJECT_VISION.md](docs/PROJECT_VISION.md)** — vision, problem, design principles, offline flow.
2. **[docs/REQUIREMENTS.md](docs/REQUIREMENTS.md)** — SRS: functional/non-functional requirements + acceptance criteria.
3. **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** — modules, data model, API contracts, traceability.
4. **[docs/PAYMENT_PROTOCOL.md](docs/PAYMENT_PROTOCOL.md)** — offline BLE/QR wire spec + two-phase exchange.
5. **[docs/SECURITY.md](docs/SECURITY.md)** — STRIDE threat model, key management, residual risks.
6. **[docs/ROADMAP.md](docs/ROADMAP.md)** — phase-based delivery plan.
7. **[docs/TODO.md](docs/TODO.md)** — current backlog and open questions.

## Status

Design phase complete (Phase 0). Implementation begins at **Phase 1 — Foundation** (crypto, identity, scaffolding). See [ROADMAP.md](docs/ROADMAP.md) and [TODO.md](docs/TODO.md).
