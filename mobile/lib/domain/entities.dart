/// Domain entities (ARCHITECTURE.md §6.1 `domain/`, §4.2 ubiquitous language).
///
/// Pure Dart, no Flutter/plugins, so coin/transfer/crypto logic is
/// unit-testable. The concrete Coin, Transfer and Wallet entities are
/// introduced by their feature tasks (issuance, offline transfer, wallet);
/// this file marks the layer and its intended contents:
///
///   Coin     — { coinId, denomination(Money), issuerKeyId, signature,
///                status, expiresAt }
///   Transfer — { coinIds, amount(Money), merchantId, nonce, timestamp,
///                payerDevicePubkey, payerSignature }   (FR-PAY-04)
///   Wallet   — held coins + monotonic op-counter + integrity tag (FR-WAL-04)
///
/// See lib/core/money.dart for the Money value object shared by all three.
library;
