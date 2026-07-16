import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Requests the runtime permissions BLE central+peripheral operations need.
///
/// Android 12+ (API 31+) needs BLUETOOTH_SCAN/ADVERTISE/CONNECT — these are
/// the gate for success below. Location is requested too (older Android
/// needs it for scanning), but never gates success: the manifest scopes
/// ACCESS_FINE_LOCATION to `maxSdkVersion="30"` (Google's recommended
/// pattern, since BLUETOOTH_SCAN's `neverForLocation` flag makes it
/// unnecessary on 12+), so on a 12+ device the OS can never grant it and
/// requiring it would make this method always fail. Known Task 7 gap: on
/// Android ≤11 a location denial silently yields empty scan results rather
/// than a surfaced error.
/// iOS prompts natively off Info.plist's NSBluetoothAlwaysUsageDescription
/// the first time a BLE API is touched, so there's nothing to request there.
class BlePermissionService {
  Future<bool> requestBlePermissions() async {
    if (!Platform.isAndroid) return true;

    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    return [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
    ].every((permission) {
      final status = statuses[permission];
      return status != null && (status.isGranted || status.isLimited);
    });
  }
}
