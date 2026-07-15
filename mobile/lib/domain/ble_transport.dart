import 'ble_message.dart';

/// BLE link lifecycle shared by both roles (ARCHITECTURE.md §6.1 `platform/ble`).
/// Customer path:  idle -> scanning -> connecting -> connected -> disconnecting -> idle
/// Merchant path:  idle -> advertising -> connected -> advertising/idle
enum BleLinkState { idle, scanning, connecting, connected, disconnecting, advertising }

const Map<BleLinkState, Set<BleLinkState>> _validTransitions = {
  BleLinkState.idle: {BleLinkState.scanning, BleLinkState.advertising, BleLinkState.connecting},
  BleLinkState.scanning: {BleLinkState.idle, BleLinkState.connecting},
  BleLinkState.connecting: {BleLinkState.connected, BleLinkState.idle},
  BleLinkState.connected: {BleLinkState.disconnecting, BleLinkState.advertising, BleLinkState.idle},
  BleLinkState.disconnecting: {BleLinkState.idle},
  BleLinkState.advertising: {BleLinkState.idle, BleLinkState.connected},
};

/// Pure-Dart, plugin-free state machine enforcing legal BLE link transitions.
/// Both [BleCentralTransport] and [BlePeripheralTransport] adapters drive one
/// of these internally instead of setting free-form state.
class BleLinkStateMachine {
  BleLinkState _state;

  BleLinkStateMachine([BleLinkState initial = BleLinkState.idle]) : _state = initial;

  BleLinkState get state => _state;

  bool canTransition(BleLinkState to) => _validTransitions[_state]?.contains(to) ?? false;

  /// Throws [StateError] if [to] isn't reachable from the current state.
  void transition(BleLinkState to) {
    if (!canTransition(to)) {
      throw StateError('Illegal BLE state transition: $_state -> $to');
    }
    _state = to;
  }
}

/// A merchant discovered while scanning (customer role).
class BleDiscoveredDevice {
  final String id;
  final String name;
  final int rssi;

  const BleDiscoveredDevice({required this.id, required this.name, required this.rssi});

  @override
  bool operator ==(Object other) =>
      other is BleDiscoveredDevice && other.id == id && other.name == name && other.rssi == rssi;

  @override
  int get hashCode => Object.hash(id, name, rssi);
}

/// Thrown for transport-level failures (link lost, connect timeout, etc).
/// Distinct from [BleMessageFormatException], which is a payload problem.
class BleTransportException implements Exception {
  final String message;
  BleTransportException(this.message);
  @override
  String toString() => message;
}

/// Customer/payer role port: scan for advertising merchants, connect, and
/// exchange JSON messages. Task 7 scope only — no signing, no coins.
abstract interface class BleCentralTransport {
  Stream<List<BleDiscoveredDevice>> scanForMerchants();
  Future<void> stopScan();

  Future<void> connect(String deviceId);
  Future<void> disconnect();

  Stream<BleLinkState> get connectionState;

  Future<void> send(BleMessage message);
  Stream<BleMessage> get incomingMessages;
}

/// Merchant role port: advertise, accept a connection, and exchange JSON
/// messages. Task 7 scope only — no signing, no coins.
abstract interface class BlePeripheralTransport {
  Future<void> startAdvertising();
  Future<void> stopAdvertising();

  Stream<BleLinkState> get connectionState;
  Stream<String?> get connectedDeviceId;

  Future<void> send(BleMessage message);
  Stream<BleMessage> get incomingMessages;
}
