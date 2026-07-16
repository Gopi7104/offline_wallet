import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/domain/ble_transport.dart';
import 'package:offline_wallet/platform/ble/ble_central_transport_impl.dart';
import 'package:offline_wallet/platform/ble/ble_permission_service.dart';

/// Customer/payer BLE transport wiring (ARCHITECTURE.md §6.1 `pay/`).
/// The real offline-payment session logic lives in
/// `payment_session_controller.dart`; these just expose the central transport
/// and permission gate for it to drive.

final bleCentralTransportProvider = Provider<BleCentralTransport>((ref) {
  return BleCentralTransportImpl();
});

final blePermissionServiceProvider = Provider((ref) => BlePermissionService());
