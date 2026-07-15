/// Task 7 placeholder GATT layout — one service, one characteristic, JSON
/// only. PAYMENT_PROTOCOL.md §6.1's real OFFER/ACK/CTRL characteristics (and
/// their own placeholder UUIDs) are Task 8 work; these are generated,
/// project-specific UUIDs to finalize alongside that design, not the §6.1
/// placeholders themselves.
abstract final class BleUuids {
  static const String service = 'c3929af1-3e8e-45d0-8961-a73cd3c041df';
  static const String messageCharacteristic = '75b74737-8a3d-42de-8d44-d1795f607f9d';

  static const String merchantLocalName = 'ODCW-Merchant';
}
