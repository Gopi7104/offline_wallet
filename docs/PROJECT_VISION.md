# Offline Digital Cash Wallet — Project Vision

**Version 1.0 | Status: Finalized Architecture Review**

---

## Executive Summary

We are building an **Offline Digital Cash Wallet**, a secure mobile payment platform for small-value transactions when internet, banking infrastructure, UPI, or cellular networks are unavailable. This is **not a replacement for UPI, banks, or PhonePe** — it is a fallback for rural connectivity, underground metros, large events, natural disasters, and temporary infrastructure failures.

The system behaves like **physical cash**: ownership transfers immediately via cryptographic proof during offline payment; settlement happens later when the merchant reconnects to the server; the customer does not need to be online to complete settlement (they transfer ownership, not permission).

**Key Architectural Decisions:**
- **Token-based wallet model** (not a balance number): wallet holds Ed25519-signed digital cash tokens issued by a simulated bank, mirroring real e-cash research.
- **Owner-signed transfers** (critical correction): transfers are signed by the current owner using a device-bound key, bound to the specific merchant/amount/nonce/timestamp, preventing replay and attribution of double-spend.
- **Offline value/velocity limits** (borrowed from RBI & ECB): transactions are capped (per-transaction, cumulative offline, velocity) to bound fraud loss.
- **Settlement with unique-spent-coin enforcement**: server maintains a unique spent-coin index to reject duplicate redemptions and maintain money-supply invariant.
- **Honest security model**: we document what software-only cannot prevent (device rollback/cloning attacks) and detect it instead via server-side double-spend flagging.

This design aligns with modern offline CBDC research (ECB, BIS, RBI) and e-cash literature (Brands, Chaum, GNU Taler, Cashu) while remaining buildable by two developers in 6–9 months.

---

## 1. The Problem We Solve

India has rapid digital-payment adoption (UPI, Google Pay, PhonePe, Paytm), yet this progress depends on:
- Internet connectivity
- Bank/UPI infrastructure availability
- Payment gateway uptime
- Cellular network coverage

When any fail, digital payments stop. Examples:
- Rural areas with poor/intermittent connectivity
- Underground metros (no signal)
- Large public events (network saturation)
- Natural disasters (infrastructure damage)
- Temporary UPI/bank outages
- Network maintenance windows

Today, physical cash is the only fallback. As societies move toward cashlessness, this dependency creates a critical reliability gap.

**Our goal:** enable small-value digital payments (~₹50–₹5,000 per transaction, ~₹50k cumulative offline) without internet, with a settlement model that matches physical cash UX.

---

## 2. Design Vision: Digital Cash, Not Digital Wallets

We are **not** building another balance-based mobile wallet. Instead, we are building an **offline-first digital cash system**.

### Key Difference

| Traditional Mobile Wallet | Offline Digital Cash Wallet |
|---|---|
| Stores a number: "Balance: ₹500" | Stores signed tokens: 5 × ₹100 tokens |
| Each payment requires server approval | Payment is cryptographically final offline |
| Customer can't spend without seller's consent | Transfers ownership immediately (like cash) |
| Seller doesn't own the money until bank approves | Seller owns signed tokens; settlement is later confirmation |

### Physical Cash Analogy

```
Bank Account: ₹10,000
        ↓
   Withdraw ₹2,000 (via app, online)
        ↓
Bank Account: ₹8,000
        ↓
Offline Wallet: ₹2,000 (as signed tokens)

After withdrawal, the ₹2,000 no longer belongs to the bank account—it belongs to you as digital cash.
```

### Token Model

The wallet's ₹500 balance is **internally** represented as:
```
Token #1001 (₹100): bank_signature(token_id=1001, value=100)
Token #1002 (₹100): bank_signature(token_id=1002, value=100)
Token #1003 (₹100): bank_signature(token_id=1003, value=100)
Token #1004 (₹100): bank_signature(token_id=1004, value=100)
Token #1005 (₹100): bank_signature(token_id=1005, value=100)
```

The user sees only `Balance: ₹500`. The token structure is an implementation detail, but it provides:
- Individual cryptographic ownership (each token is independently signed and verifiable)
- Stronger fraud detection (token integrity tied to specific denomination)
- Realistic payment architecture (closer to e-cash research)
- Better settlement auditability

---

## 3. Core Design Principles

### 3.1 Offline-First Payments

1. Customer loads digital cash while online (bank balance decreases immediately).
2. Internet becomes unavailable.
3. Customer scans Merchant QR code.
4. Bluetooth Low Energy (BLE) connection established.
5. Customer **signs and transfers** digital tokens to merchant (using a device-bound key).
6. Merchant receives tokens and **becomes the owner**.
7. Payment is **cryptographically final** at this point.
8. When merchant reconnects, tokens are uploaded and settled (merchant credited immediately).

**Key insight:** the customer is not required during settlement. They transferred ownership; settlement is just confirmation.

### 3.2 Owner-Signed Transfers (Critical)

**Bearer tokens alone are insufficient.** An Ed25519 signature by the bank proves the bank issued the coin, not that only one wallet holds it. A compromised wallet can copy and transfer the same token to two merchants.

**Solution:** Transfers are **owner-signed**, binding the transfer to a specific merchant, amount, and session:

```
Transfer {
  coin_ids: [1001, 1002],
  amount: 200,
  merchant_id: "M12345",
  nonce: "challenge_from_merchant_qr",
  timestamp: "2026-07-13T14:32:00Z",
  owner_signature: Ed25519_sign(transfer_object, device_private_key)
}
```

**Benefits:**
- Transfer cannot be replayed to a second merchant (nonce + merchant_id binding).
- Double-spend can be attributed to the original owner (their signature is on both transfers).
- Merchant can verify offline that this transfer is intended for them.

### 3.3 Offline Value & Velocity Limits

Following RBI and ECB offline CBDC frameworks, we impose **limits to bound fraud loss** if a device is compromised:

- **Per-transaction limit:** ₹5,000 maximum per offline payment.
- **Cumulative offline limit:** ₹50,000 maximum without reconnecting to the server.
- **Velocity limit:** maximum 5 offline transactions per 24 hours (rolling window).

After cumulative limit is reached, the device must reconnect to the server to sync and refresh the offline allowance.

**Rationale:** these limits prevent a single compromised device from draining arbitrarily large value. Real CBDC systems (ECB, RBI UPI Lite, Visa offline) use similar caps.

### 3.4 Settlement & Unique-Spent-Coin Enforcement

**Money-Supply Invariant:** `Issued Tokens = Tokens in Wallets + Tokens Redeemed`

When a merchant uploads redeemed tokens:

1. Server verifies bank signature over the token.
2. Server checks the **unique spent-coin index**: has this coin ID been redeemed before?
   - **If first redemption:** mark as redeemed, credit merchant account.
   - **If duplicate:** this is a double-spend. Flag the original payer; reject the duplicate redemption.
3. Server updates money-supply ledger (outstanding → redeemed).
4. Merchant receives credit **immediately** (not waiting for customer confirmation).

This is **detect-and-flag, not prevent**. We cannot prevent a rooted device from copying a wallet; we detect it at settlement via the unique spent-coin index and flag it for risk/fraud teams.

### 3.5 User Roles: Symmetric Design

Every user has:
- A **Customer Account** (bank-linked balance, load/fund wallet).
- A **Merchant Mode** (can receive payments from other customers).
- A **Merchant Wallet** (holds received digital tokens until settlement).
- A **Merchant QR Code** (generated on-demand, not pre-registered).

No separate merchant registration. This keeps onboarding simple while maintaining accountability (every merchant has an audit trail).

---

## 4. The Offline Payment Flow (Detailed)

### Step 1: Load (Online, Bank-Linked)

User opens the app, is authenticated via Firebase, and:

```
Input: Bank account has ₹10,000
User requests: Load ₹500 into offline wallet

Server:
  1. Verify user authentication + bank account.
  2. Debit bank account by ₹500.
  3. Issue 5 signed digital tokens (₹100 each).
  4. Encrypt tokens with device key and sync to phone.

Output: Offline wallet now holds 5 tokens (₹500)
        Bank account reduced to ₹9,500
```

### Step 2: Offline Payment (No Internet)

Customer is offline. Wants to buy groceries from Merchant.

```
Merchant:
  1. Opens app in Merchant Mode.
  2. Generates a fresh Merchant QR code (includes merchant_id, timestamp, nonce).

Customer:
  1. Scans Merchant QR.
  2. Enters amount to pay: ₹200.
  3. App constructs a Transfer object:
     {
       coin_ids: [1001, 1002],          // two ₹100 tokens
       amount: 200,
       merchant_id: "M12345",
       nonce: "abc123def456",            // from QR
       timestamp: "2026-07-13T14:32:00Z",
       owner_signature: (device-signed)
     }
  4. Establishes BLE connection to merchant's phone.
  5. Sends Transfer + tokens over BLE.
  6. Merchant verifies:
     - Bank signature over tokens (offline, using cached bank public key).
     - Owner signature matches the transfer details.
     - Nonce matches the QR.
     - Timestamp is fresh (within a few minutes).
  7. Merchant accepts and stores the Transfer as a redemption proof.
  8. Customer wallet deletes the tokens (change-making: customer keeps ₹0 unspent).

Output: Tokens now belong to the merchant. Payment is complete.
```

### Step 3: Settlement (Later, Online)

Merchant reconnects to the internet.

```
Merchant:
  1. App automatically detects connectivity.
  2. Uploads all received Transfer objects + tokens.

Server:
  1. Verify bank signature over each token.
  2. Check unique spent-coin index:
     - If token never seen before: mark as redeemed, credit merchant.
     - If token already redeemed by another merchant: **double-spend detected**. Flag payer for fraud. Reject this redemption.
  3. Update ledger (token status: issued → in_wallet → redeemed).
  4. Credit merchant account: ₹200.
  5. Return receipt.

Output: Merchant account has ₹200 credited. Payer is flagged if double-spend detected.
        Customer NOT required to be online.
```

---

## 5. Security Model & Limitations

### 5.1 What We Achieve

- **Offline finality:** payment is cryptographically complete; merchant owns tokens.
- **Replay prevention:** owner signature + nonce binding stops replay to a second merchant.
- **Attribution:** if a token is spent twice, we know which customer (private key) signed both transfers.
- **Settlement integrity:** unique spent-coin index + ledger invariant prevent undercounting or double-counting redeemed value.
- **Tamper detection:** AES-256 encrypted wallet + HMAC/signed state + offline nonce counter detect modifications.

### 5.2 What We Do NOT Prevent (Documented Limitations)

**Device Rollback / Cloning:** A sophisticated attacker with root access or stolen backup can:
- Restore an old wallet backup (reverting tokens to a previous state).
- Clone the encrypted wallet + device key to multiple devices.
- Spend the same tokens multiple times.

**Why we can't prevent this:** consumer phones lack reliable **secure monotonic counters**. Without hardware-backed rollback protection (secure element / StrongBox with real counter), rollback cannot be prevented in software. Android StrongBox and iOS Secure Enclave provide better protections, but consumer device adoption is limited.

**What we do instead:** We **detect** double-spend at settlement via the unique spent-coin index and flag the payer for fraud/manual review. We document this openly.

**Device Compromise:** If a phone is compromised (rooted / jailbroken):
- Device keys can be extracted at runtime.
- Plaintext wallet state can be read from memory.
- Offline limits can be bypassed (the app enforces them; a modified app doesn't).

**Mitigations (defense-in-depth, not guarantees):**
- Device binding (keys registered with the server via attestation).
- Root/jailbreak detection (not a guarantee, but a tripwire for alerts).
- Velocity limits (cap loss).
- Server-side double-spend detection.

### 5.3 Security Principles (Implementation)

1. **Cryptographic Primitives:**
   - Ed25519 for digital signatures (bank issuance, owner transfers).
   - AES-256-GCM for wallet encryption.
   - HKDF for key derivation.
   - Secure random for nonces/token IDs.

2. **Key Management:**
   - Bank signing key: server-side, never exposed.
   - Device private key: stored in Android Keystore / iOS Keychain (hardware-backed if available).
   - Wallet encryption key: derived from device key, never exported.

3. **Wallet Storage:**
   - Encrypted wallet file on phone storage.
   - Encryption key in device keystore.
   - HMAC over wallet state to detect tampering.
   - Offline monotonic counter (per-token nonce) to bind tokens to device.
   - Sync to server logs as a rollback tripwire.

4. **Protocol Security:**
   - BLE: application-layer authentication via owner signature (BLE link security is not sufficient).
   - QR: no sensitive data in QR itself; nonce is public.
   - Replay prevention: nonce + merchant_id + timestamp binding.
   - Freshness: timestamp checked by merchant (within a few minutes).

5. **Fraud Detection:**
   - Unique spent-coin index: detects double-redemption immediately.
   - Device fingerprinting: alert on new/unknown device.
   - Velocity monitoring: flag unusual patterns (e.g., ₹50k offline limit hit within hours).
   - Payer attribution: both copies of a double-spent token carry the same owner signature.

---

## 6. Simulated Banking System (Backend)

The backend is **not** a simple balance database. It is a realistic banking core simulation with:

### 6.1 Core Entities

**Accounts:**
- Customer accounts (linked to Firebase user ID, bank balance).
- Merchant accounts (can receive payments, settlement balance).
- Bank account (float management, issued-vs-outstanding tracking).

**Wallets:**
- Offline wallet (customer side): encrypted, holds tokens.
- Merchant wallet (server side): holds received tokens awaiting settlement.

**Tokens:**
- Digital cash tokens (unique ID, denomination, bank signature, status).
- Status lifecycle: `issued` → `in_wallet` → `transferred_to_merchant` → `redeemed` → `void`.

**Transactions:**
- Load events (bank balance → offline wallet).
- Transfer events (offline payment proof, merchant receives).
- Redemption events (merchant settles, tokens cleared).

### 6.2 Settlement Engine

**Core Responsibilities:**

1. **Idempotent Redemption:** accept merchant upload, check spent-coin index, reject duplicates.
2. **Exactly-Once Guarantee:** unique constraint on `(token_id, redeemed_by_merchant_id)` prevents double-counting.
3. **Money-Supply Invariant:** periodic reconciliation: `issued_tokens = tokens_in_customer_wallets + tokens_in_merchant_wallets + tokens_redeemed`.
4. **Double-Spend Attribution:** log both redemption attempts; mark payer for fraud review.
5. **Merchant Credit:** update merchant balance immediately upon successful settlement.

### 6.3 Ledger & Audit

**Immutable Append-Only Ledger:**
- Every transaction is an immutable ledger entry (event sourced).
- Entries include: timestamp, actor (customer/merchant/bank), action (load/transfer/settle), amounts, signatures, state change.
- Ledger is the source of truth for audit, reconciliation, and dispute resolution.

**Reconciliation Jobs:**
- Daily: sum issued tokens, sum outstanding tokens, sum redeemed tokens. Verify invariant.
- Weekly: merchant settlement reconciliation, orphaned tokens, stale transfers.
- Monthly: customer-level reconciliation, flagged fraud, velocity analysis.

---

## 7. Technology Stack

| Component | Technology | Rationale |
|---|---|---|
| Frontend (Mobile) | Flutter | Cross-platform (iOS/Android), fast iteration, security libraries available. |
| Backend | Node.js + Express.js | Fast iteration, ecosystem maturity, JavaScript familiarity. |
| Database | PostgreSQL | Strong ACID guarantees (critical for ledger), JSON support, proven at scale. |
| Authentication | Firebase Auth | Fast setup, handles user identity; backend verifies tokens. |
| Offline Comms | QR Code + BLE | QR for initial pairing (merchant discovery), BLE for value transfer. |
| Cryptography | Ed25519 (libsodium/tweetnacl) + AES-256 (crypto.subtle / libsodium) | Well-audited, library support in Flutter/Node. |
| Key Storage | Android Keystore / iOS Keychain | Hardware-backed if available; standard OS integration. |

---

## 8. Architectural Layers

### 8.1 Backend (Node.js)

```
┌─────────────────────────────────────────┐
│         API Layer (Express)             │
│  /load, /transfer, /redeem, /sync       │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────▼──────────────────────┐
│     Domain Logic Layer                  │
│  - Wallet (load/redeem)                 │
│  - Transfer (verify owner sig)          │
│  - Settlement (spent-coin index)        │
│  - Ledger (append-only events)          │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────▼──────────────────────┐
│     Persistence Layer (PostgreSQL)      │
│  - Accounts, Tokens, Ledger             │
│  - Spent-coin index (unique constraint) │
│  - Merchant wallets, transactions       │
└─────────────────────────────────────────┘
```

### 8.2 Flutter (Mobile)

```
┌─────────────────────────────────────────┐
│         UI Layer (Screens)              │
│  Load, Send, Receive, History           │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────▼──────────────────────┐
│     Business Logic Layer                │
│  - PaymentUseCase, SettlementUseCase    │
│  - OfflinePaymentProtocol               │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────▼──────────────────────┐
│     Local Storage Layer                 │
│  - Encrypted wallet (AES-256)           │
│  - SQLite (transactions, token status)  │
│  - Keystore integration                 │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────▼──────────────────────┐
│     Network Layer                       │
│  - Firebase Auth, Backend API, BLE      │
└─────────────────────────────────────────┘
```

---

## 9. Development Roadmap (6–9 Months, 2 Developers)

### Phase 1: Foundation (Weeks 1–4)

**Goals:** infrastructure, crypto primitives, identity setup.

- **Backend:**
  - Express.js scaffolding, PostgreSQL setup, basic user/account models.
  - Firebase integration (auth tokens verification).
  - Token schema (issuer signature, denomination, ID, status).
  - Ed25519 signing/verification (libsodium).

- **Mobile:**
  - Flutter project setup, Firebase Auth integration.
  - Device key generation (Android Keystore, iOS Keychain).
  - Wallet encryption (AES-256-GCM) + basic storage.
  - Crypto library setup (tweetnacl/libsodium).

**Definition of Done:** users can sign up, backend can sign tokens, mobile can encrypt/decrypt a wallet.

---

### Phase 2: Core Wallet & Load (Weeks 5–8)

**Goals:** load digital cash, offline wallet management.

- **Backend:**
  - `/load` endpoint: debit customer bank account, issue signed tokens, sync to customer.
  - Token issuance logic (unique ID generation, bank signature).
  - Ledger events (load events, append-only log).

- **Mobile:**
  - Load UI (amount picker, confirmation).
  - Local wallet storage (token list, encrypted).
  - Offline token verification (bank signature check using cached public key).
  - Sync from server (receive issued tokens, store encrypted).

**Definition of Done:** end-to-end: customer loads ₹500, wallet shows 5 tokens, can be encrypted/decrypted locally.

---

### Phase 3: Offline Payment Protocol (Weeks 9–14)

**Goals:** owner-signed transfers, BLE messaging, merchant receive.

- **Backend:**
  - Transfer verification logic (owner signature validation, nonce + merchant_id binding).
  - Merchant wallet storage (received transfers + tokens).

- **Mobile:**
  - Merchant Mode (generate QR with merchant_id, nonce, timestamp).
  - BLE setup (pairing, secure channel at app layer).
  - Transfer signing (owner signs `{coin_ids, amount, merchant, nonce, timestamp}`).
  - Transfer send (BLE transmit).
  - Transfer receive & validation (verify owner sig, bank sig, nonce freshness).
  - Token deletion on sender side (after successful transfer).

**Definition of Done:** Customer A scans Merchant B's QR → BLE connects → A sends ₹200 (2 tokens) → B receives + verifies offline → A's wallet loses tokens → B's merchant wallet shows received tokens.

---

### Phase 4: Settlement & Ledger (Weeks 15–18)

**Goals:** server-side settlement, unique spent-coin index, money-supply invariant.

- **Backend:**
  - `/settle` or `/upload-tokens` endpoint: merchant uploads received transfers.
  - Spent-coin index: check if token already redeemed, reject duplicates.
  - Settlement logic: verify signatures, mark tokens as redeemed, credit merchant.
  - Money-supply reconciliation job: issued = outstanding + redeemed.
  - Ledger audit trail: every settlement event logged.

- **Mobile:**
  - Auto-sync on reconnect: detect connectivity, upload pending merchant transfers.
  - Sync status UI (pending settlements, completion feedback).

**Definition of Done:** Merchant uploads 2 tokens → server verifies → merchant credited → money-supply invariant holds → uploading again rejects (double-spend detected).

---

### Phase 5: Offline Limits & Risk (Weeks 19–22)

**Goals:** enforce velocity caps, fraud flagging, device binding.

- **Backend:**
  - Velocity monitoring: flag unusual transaction patterns.
  - Device registration: one device per customer (device fingerprinting + attestation).
  - Offline limit checks: reject loads/transfers if offline allowance exceeded.

- **Mobile:**
  - Offline counter (per-transaction + cumulative): blocks payment if limits hit.
  - Sync limit reset: reconnecting refreshes offline allowance.
  - Root/jailbreak detection (as a defense-in-depth tripwire).

**Definition of Done:** Customer hits ₹50k offline limit → cannot pay offline until reconnect → after sync, limit resets.

---

### Phase 6: Testing & Hardening (Weeks 23–26)

**Goals:** security review, end-to-end tests, documentation.

- **Backend:**
  - Unit tests (token signing, settlement logic, money-supply invariant).
  - Integration tests (load → transfer → settle).
  - Double-spend simulation (same token uploaded by two merchants; verify detection).
  - Ledger tests (invariant checks, reconciliation).

- **Mobile:**
  - Encryption/decryption tests (wallet storage integrity).
  - Transfer signing tests (owner sig validation).
  - BLE protocol tests (replay, tampering).
  - Integration tests (offline payment flow end-to-end).

- **Documentation:**
  - Threat model (what we prevent, what we detect, what is documented limitation).
  - API specification.
  - Security guidelines for operations (monitoring, fraud flags).

**Definition of Done:** Test coverage > 70%, no critical security findings, architecture documented.

---

## 10. Known Limitations & Honest Disclaimers

1. **No Offline Double-Spend Prevention (Software-Only):** A rooted device can clone/rollback a wallet and spend the same tokens twice. We detect this at settlement, not prevent it. This is unavoidable without a secure element.

2. **No Secure Monotonic Counter on Consumer Phones:** Android StrongBox and iOS Secure Enclave have counters, but coverage is inconsistent. We cannot reliably detect rollback on older devices.

3. **Device Compromise is a Total Loss:** If a phone is compromised (rooted), device keys can be extracted and the wallet becomes fully controllable by an attacker. Offline limits and fraud flags mitigate (not eliminate) this risk.

4. **No Perfect Privacy:** Every transaction is logged on the server (required for settlement & fraud detection). This is not an anonymity-focused system; it is focused on offline availability and fraud detection.

5. **Small-Value Only:** The system is designed for ₹50–₹50k transactions. Large-value offline payments require additional checks (PIN, biometric, time delays) not in this prototype.

6. **No Regulatory License:** This is a prototype. Deploying to production would require RBI license/approval, which is outside the scope of this project.

---

## 11. Design Decisions: Trade-Offs & Why We Chose This Way

| Decision | Alternative | Why We Chose This |
|---|---|---|
| **Owner-signed transfers (not bearer tokens)** | Issue bearer tokens signed only by bank | Bearer tokens can be copied; owner signatures enable attribution and prevent replay. Aligns with real e-cash research (Brands, Chaum). |
| **Offline limits (not unlimited)** | Allow any value offline | Limits bound fraud loss from device compromise. Matches RBI/ECB CBDC frameworks. Practical for prototype. |
| **Detect double-spend (not prevent)** | Require secure element (not practical for prototype) | Software cannot prevent rollback/cloning on consumer phones. Detection + flagging is realistic and provides recovery path (fraud review, dispute). |
| **Token-based wallet (not balance number)** | Store ₹500 as a single number | Tokens provide individual cryptographic ownership, match e-cash literature, and enable better audit/settlement transparency. |
| **Simulated bank backend (not real APIs)** | Integrate with actual ICICI/HDFC/UPI | Enables rapid prototyping without regulatory/legal complexity. Provides realistic banking simulation. |
| **Symmetric merchant mode (not separate merchant app)** | Separate registration, merchant app | Simpler UX, faster onboarding, still maintains audit trail. Suitable for prototype. |
| **Flutter + Node.js (not Kotlin/Swift + Java/Python)** | Native Android/iOS | Cross-platform iteration, community libraries for crypto, Firebase integration. Faster for 2-dev team. |
| **BLE + QR (not NFC or other)** | NFC, custom hardware, internet-only | BLE widely available, QR for easy pairing, no special hardware. NFC limits device types; internet-only defeats offline goal. |

---

## 12. Alignment with Real Payment Systems Research

This design draws from and aligns with:

1. **Chaumian E-Cash & Blind Signatures** (Chaum, 1983): We use signed coins, but add owner signatures for attribution.

2. **Brands/CHL Offline E-Cash** (Brands, 1995; Chaum–Hertzberg–Laplante, 1999): Double-spend detection and cheater identification via cryptography. We simplify for a prototype (detect at settlement, not cryptographic cut-and-choose).

3. **ECB & BIS Offline CBDC Work:** Design principles for offline-first central bank digital currencies. We borrow transaction limits, settlement models, and money-supply invariants.

4. **RBI Offline Digital Payments Framework:** India-specific offline limits (₹5k transaction, ₹50k cumulative). We align with these for regulatory realism.

5. **GNU Taler & Cashu (Ecash):** Modern open-source e-cash implementations. We study their token model, settlement, and fraud detection.

6. **NPCI UPI Lite / UPI123Pay:** India's existing offline-mode UPI variants. We learn from their velocity limits and step-up authentication.

---

## 13. Success Criteria

The project is considered successful when:

1. **Offline Payment Works End-to-End:** Customer loads cash → goes offline → scans merchant QR → transfers tokens over BLE → merchant receives → settlement credits merchant (customer not required online).

2. **Double-Spend is Detected at Settlement:** Two merchants upload the same token → server rejects the second, flags the payer.

3. **Money-Supply Invariant Holds:** Reconciliation job confirms `issued = outstanding + redeemed` ±0.

4. **Offline Limits are Enforced:** Customer cannot exceed ₹50k cumulative offline; limit resets after reconnect.

5. **Security Properties are Tested:** Transfer replay is blocked, token tampering is detected, device compromise is documented and monitored.

6. **Architecture Supports Future Growth:** Clear boundaries (identity, wallet, issuance, settlement, ledger), minimal coupling, suitable for moving to real bank APIs / RBI approval pathway.

7. **Two Developers Can Maintain It:** Code is well-structured, documented, and modular. A new developer can onboard in 1–2 weeks.

---

## 14. Next Steps

1. **Architecture Detail:** Finalize database schema, API spec, Flutter architecture.
2. **Threat Model:** Complete formal threat analysis (STRIDE, security property proofs).
3. **Development Roadmap:** Break Phase 1 into 1-week sprints, assign tasks.
4. **Prototype Codebase:** Init Flutter + Node.js repos, set up CI/CD, cryptography tests.

---

## Appendix: Research References

- **Chaum, D.** (1983). "Blind Signatures for Untraceable Payments." *Advances in Cryptology — CRYPTO '83*. Springer.
- **Brands, S. A.** (1995). "Untraceable Off-line Cash in Wallets with Observers." *CRYPTO '95*. Springer.
- **Chaum, D., Hertzberg, J., & Laplante, A.** (1999). "Offline Shoppers: Practical Solutions for Online Privacy-Preserving Transactions."
- **ECB.** (2023). "CBDC Design Choices: Offline Payment Mechanisms." *Digital Euro Project*.
- **BIS.** (2023). "Central Bank Digital Currencies: Offline Transactions and Privacy." *Technical Report*.
- **RBI.** (2022). "Framework for Regulated Digital Rupee Services." *RBI Guidelines*.
- **GNU Taler:** https://taler.net/ (open-source e-cash reference implementation).
- **Cashu / Ecash:** https://github.com/cashubtc/cashu (modern ecash library).

---

**Document Status:** Finalized | **Last Updated:** 2026-07-13 | **Next Review:** After Phase 1 infrastructure complete.
