/// Data layer (ARCHITECTURE.md §6.1 `data/`, §6.2).
///
/// Implements domain-defined repository interfaces using:
///   • local encrypted DB — Drift over SQLCipher (ADR-6), data key wrapped
///     by a keystore key (NFR-SEC-01); wallet state carries an HMAC +
///     monotonic op-counter (FR-WAL-04);
///   • sync engine — idempotent, resumable push/pull (FR-SYNC-*);
///   • api client — HTTPS/JSON to the backend (§5.6).
///
/// Concrete adapters land with their feature tasks.
library;
