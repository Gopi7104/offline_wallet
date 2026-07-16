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

---

## Quick Start

### Prerequisites

**Backend:**
- Node.js ≥ 20
- PostgreSQL 13+
- npm/yarn

**Mobile:**
- Flutter ≥ 3.22.0 (Dart ≥ 3.4.0)
- Android 10+ SDK / Xcode 14+ for iOS
- Android emulator or physical device

### Setup

#### 1. Backend

```bash
cd backend

# Install dependencies
npm install

# Copy environment template
cp .env.example .env

# Update .env with your PostgreSQL connection
# Default: postgres://wallet:wallet@localhost:5432/offline_wallet

# Run database migrations
npm run migrate

# (Optional) Seed dev data
# See tests/ for example data loaders
```

#### 2. Mobile

```bash
cd mobile

# Get Flutter dependencies
flutter pub get

# (Optional) Generate app icons
# dart run flutter_launcher_icons

# (Optional) Run code generation (for future features like Drift, Riverpod)
# flutter pub run build_runner build
```

### Running the Project

#### Backend (Development)

```bash
cd backend

# Start dev server with hot reload (port 3000)
npm run dev

# Build production bundle
npm run build
npm start

# Run tests
npm test

# Type-check
npm run typecheck
```

#### Mobile (Android)

```bash
cd mobile

# List connected devices
flutter devices

# Run on default device
flutter run

# Run with debug logging
flutter run -v

# Build APK
flutter build apk

# Run tests
flutter test
```

#### Mobile (iOS)

```bash
cd mobile

# Install pod dependencies (macOS/iOS only)
cd ios
pod install
cd ..

# Run on simulator
flutter run -d iPhone

# Run on physical device (requires provisioning profile)
flutter run -d <device-id>

# Build IPA
flutter build ipa
```

### Development Workflow

1. **Backend changes:** `npm run dev` watches TypeScript files; hot-reload on save.
2. **Mobile changes:** `flutter run` watches Dart files; hot-reload on save.
3. **Database migrations:** Create `.sql` files in `backend/migrations/` and run `npm run migrate`.
4. **Testing backend:** `npm test` runs Jest tests in `backend/tests/`.
5. **Testing mobile:** `flutter test` runs tests in `mobile/test/`.

### Project Structure

```
backend/
  src/              TypeScript source (domain, app, platform layers)
  migrations/       Database schema + data migrations
  tests/            Integration & unit tests
  jest.config.js    Test configuration
  package.json      Dependencies & scripts

mobile/
  lib/              Flutter app (features, domain, data, platform)
  test/             Unit & widget tests
  integration_test/ End-to-end tests
  android/          Android-specific code
  ios/              iOS-specific code
  pubspec.yaml      Dependencies & configuration

docs/
  PROJECT_VISION.md    High-level vision & design principles
  REQUIREMENTS.md      Functional & non-functional requirements
  ARCHITECTURE.md      System design & API contracts
  PAYMENT_PROTOCOL.md  Offline payment BLE/QR protocol
  SECURITY.md          Threat model & key management
  ROADMAP.md           Phase-based delivery plan
  TODO.md              Current backlog & open questions

CLAUDE.md             Development guidance for Claude Code
```

### Troubleshooting

**Backend won't start:**
- Check PostgreSQL is running: `psql -h localhost -U wallet -d offline_wallet`
- Verify .env DATABASE_URL is correct
- Run migrations: `npm run migrate`

**Mobile build fails:**
- Clear build cache: `flutter clean`
- Get dependencies: `flutter pub get`
- Check Flutter is installed: `flutter --version`
- For iOS: `cd ios && pod repo update && pod install && cd ..`

**Tests fail:**
- Backend: ensure test DB exists (migrations auto-create `offline_wallet_test`)
- Mobile: run `flutter pub get` before `flutter test`

### Next Steps

- Read [docs/PROJECT_VISION.md](docs/PROJECT_VISION.md) for architecture overview
- Check [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for API contracts and data model
- See [CLAUDE.md](CLAUDE.md) for development guidelines
- Track progress in [docs/ROADMAP.md](docs/ROADMAP.md) and [docs/TODO.md](docs/TODO.md)
