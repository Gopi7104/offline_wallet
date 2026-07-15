import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/domain/ble_transport.dart';
import 'package:offline_wallet/platform/ble/ble_peripheral_transport_impl.dart';
import 'package:offline_wallet/platform/ble/ble_permission_service.dart';

/// Merchant BLE transport wiring (ARCHITECTURE.md §6.1 `receive/`).
/// The real receive-payment session logic lives in
/// `merchant_receive_controller.dart`; these just expose the peripheral
/// transport and permission gate for it to drive.

final blePeripheralTransportProvider = Provider<BlePeripheralTransport>((ref) {
  return BlePeripheralTransportImpl();
});

final blePeripheralPermissionServiceProvider = Provider((ref) => BlePermissionService());
