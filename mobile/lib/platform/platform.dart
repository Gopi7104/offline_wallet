/// Platform layer (ARCHITECTURE.md §6.1 `platform/`, §6.3).
///
/// Platform-channel and plugin adapters, isolated behind domain ports:
///   • keystore   — Android Keystore / iOS Keychain+Secure Enclave,
///                  non-exportable device key (FR-ID-02, NFR-CMP-02);
///   • ble        — flutter_blue_plus value transfer;
///   • qr         — mobile_scanner (scan) + qr generation (merchant);
///   • connectivity — online/offline detection for the sync trigger.
///
/// Concrete adapters land with their feature tasks (auth/BLE/QR).
library;
