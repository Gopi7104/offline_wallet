import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:offline_wallet/domain/ble_transport.dart';
import 'package:offline_wallet/platform/ble/ble_peripheral_transport_impl.dart';

// On-device BLE smoke test (Task 7). Runs on the PHYSICAL device and drives
// the real `universal_ble` peripheral adapter directly — no backend, no
// Merchant Mode gate — to confirm advertising actually starts on real
// hardware without crashing.
//
//   verify: flutter test integration_test/ble_merchant_smoke_test.dart -d <deviceId>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('merchant peripheral transport advertises without crashing', (tester) async {
    final transport = BlePeripheralTransportImpl();
    final states = <BleLinkState>[];
    final sub = transport.connectionState.listen(states.add);

    await transport.startAdvertising();
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(states, contains(BleLinkState.advertising));

    await transport.stopAdvertising();
    await sub.cancel();
  });
}
