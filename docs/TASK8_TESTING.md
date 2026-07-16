# Task 8 — Two-Phone Offline Payment: Test Guide

This walks the full offline payment on **two Android phones** with **no Mac/backend/internet needed**. Task 8 mints and spends digital-cash tokens entirely on-device.

- **Phone C** = Customer (pays)
- **Phone M** = Merchant (receives)

Both need: Android 10+, **Bluetooth ON**, **Location ON** (Android requires location services enabled for BLE *scanning* to return results, even though we don't use location data), and the app installed.

---

## Build & install the APK

On the dev Mac (once):

```bash
cd mobile
flutter build apk --release          # → build/app/outputs/flutter-apk/app-release.apk
```

Install on each phone (USB) or share the `.apk` file and sideload:

```bash
adb -s <PHONE_C_SERIAL> install -r build/app/outputs/flutter-apk/app-release.apk
adb -s <PHONE_M_SERIAL> install -r build/app/outputs/flutter-apk/app-release.apk
```

> No `--dart-define` / backend is required. Loading money works offline (tokens are minted on-device). If the phone happens to reach the dev backend it will also record the balance server-side, but that's optional.

To prove it's truly offline: put **both phones in Airplane mode, then turn Bluetooth back ON.**

---

## The 10 steps

| # | Step | Where | What to do | Expected |
|---|------|-------|-----------|----------|
| 1 | **Create customer wallet** | Phone C | Open app → Get Started → **Continue as Guest** → set a 6-digit **app PIN** | Lands on Home; **BALANCE ₹0.00** |
| 2 | **Load money** | Phone C | Home → **Wallet** → **Load Money** → enter **500** → Continue → Review → Continue → pick bank → Continue → enter any 6-digit UPI PIN → Verify | "Money Added"; Home **BALANCE ₹500.00** (offline cash minted as ₹200+₹200+₹100 tokens) |
| 3 | **Enable merchant mode** | Phone M | Home → toggle **Merchant Mode** ON | Toggle turns on; "Open Merchant Dashboard" appears (works offline) |
| 4 | **Generate a QR** | Phone M | Home → **Merchant** (or Open Merchant Dashboard) → **Receive Payment (BLE)** → enter **100** → **Show QR & Start**. Grant the Bluetooth/Nearby-devices permission when asked | QR shows; status **"Waiting for customer…"** (advertising) |
| 5 | **Scan the QR** | Phone C | Home → **Pay** → **Scan QR** → point camera at Phone M's QR. Grant Bluetooth when asked | Merchant summary (₹100) → **Confirm & Pay** → PIN/fingerprint → **"Paying…"** (Connecting → Sending) |
| 6 | **Complete payment** | both | Wait a few seconds | Phone C: **"Payment sent"** (₹100, tokens sent). Phone M: status **"Payment received"** |
| 7 | **Customer balance decreases** | Phone C | Tap Done → look at Home | **BALANCE ₹400.00** (was ₹500) |
| 8 | **Merchant pending increases** | Phone M | Look at the receive screen | **Pending Settlement ₹100.00**, **Tokens received: 1** |
| 9 | **Restart the app** | Phone C | Swipe the app away from Recents (fully close), reopen | **BALANCE still ₹400.00** — offline cash is persisted to secure storage. Pay again to confirm it still works |
| 10 | **Invalid cases** | — | See below | Each is rejected cleanly; no value moves |

### Step 10 — invalid cases

- **Cancel:** start a payment on Phone C, and on the **"Paying…"** screen tap **Cancel** → dialog "Payment cancelled" → Home balance unchanged. (Merchant returns to waiting.)
- **Insufficient balance:** on Phone M request an amount larger than Phone C's offline cash (e.g. request ₹1000 when C has ₹400). On Phone C after scanning, **Confirm & Pay** shows an inline error ("not enough offline cash") **before** any BLE/auth — nothing is sent.
- **Duplicate payment:** complete one payment, then (without stopping the merchant) have the customer retry/reconnect for the *same* request → the merchant re-sends its confirmation but **does not double-credit** (Pending Settlement stays ₹100, token count unchanged).
- **BLE disconnect:** during "Paying…", move the phones far apart or turn off the merchant's Bluetooth → Phone C shows "connection was lost", **tokens are retained** (balance unchanged).

---

## Tips / gotchas

- **Keep both apps in the foreground** during the payment — background BLE isn't supported in the prototype (iOS/Android).
- If scanning finds no merchant: confirm Phone M shows "Waiting for customer…", both Bluetooth radios are ON, Location is ON, and the phones are within ~1–2 m.
- First BLE use prompts for the **Nearby devices / Bluetooth** permission — allow it. If you previously denied it, enable it in Android Settings → Apps → Offline Wallet → Permissions.
- Two **Android** phones is the tested target (both can act as BLE peripheral). iOS↔Android may work but is unverified.

## Known prototype limitations (by design — Task 9)

- **No real crypto / no settlement / no double-spend detection yet.** Tokens carry placeholder signatures; the merchant holds received tokens as *Pending Settlement* only.
- The customer connects to the **first** merchant advertising the service; if two merchants advertise nearby it may pick the wrong one — it then detects the `merchantId`/`nonce` mismatch from the OFFER and cancels.
- Large payments (many tokens) rely on BLE message chunking that is unit-tested but not yet two-phone verified on hardware.
- The customer's Home balance shows **offline cash** (the local tokens), not a bank/settled balance.
