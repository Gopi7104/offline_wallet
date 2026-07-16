import 'dart:async';

import 'package:offline_wallet/domain/ble_message.dart';
import 'package:offline_wallet/domain/ble_transport.dart';

/// In-memory BLE fakes for Task-8 protocol tests. `LinkedCentral` and
/// `LinkedPeripheral` can be driven standalone (emit* helpers) for
/// single-controller tests, or paired via [LinkedFakeTransport] so
/// central.send↔peripheral.incoming for a full customer↔merchant session.

class LinkedCentral implements BleCentralTransport {
  LinkedPeripheral? peer;
  final _incoming = StreamController<BleMessage>.broadcast();
  final _link = StreamController<BleLinkState>.broadcast();
  final _scan = StreamController<List<BleDiscoveredDevice>>.broadcast();
  final List<BleMessage> sent = [];
  bool failConnect = false;
  int connectCalls = 0;

  @override
  Stream<List<BleDiscoveredDevice>> scanForMerchants() {
    scheduleMicrotask(() {
      if (!_scan.isClosed) {
        _scan.add(const [BleDiscoveredDevice(id: 'merchant-1', name: 'Merchant', rssi: -40)]);
      }
    });
    return _scan.stream;
  }

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> connect(String deviceId) async {
    connectCalls++;
    if (failConnect) throw BleTransportException('connect failed');
    emitLink(BleLinkState.connecting);
    emitLink(BleLinkState.connected);
    peer?.onPayerConnected('payer-1');
  }

  @override
  Future<void> disconnect() async {
    emitLink(BleLinkState.idle);
    peer?.onPayerDisconnected();
  }

  @override
  Stream<BleLinkState> get connectionState => _link.stream;

  @override
  Future<void> send(BleMessage message) async {
    sent.add(message);
    peer?.deliver(message);
  }

  @override
  Stream<BleMessage> get incomingMessages => _incoming.stream;

  // test drivers
  void deliver(BleMessage m) {
    if (!_incoming.isClosed) _incoming.add(m);
  }

  void emitIncoming(BleMessage m) => deliver(m);
  void emitLink(BleLinkState s) {
    if (!_link.isClosed) _link.add(s);
  }

  void emitMalformed() {
    if (!_incoming.isClosed) _incoming.addError(BleMessageFormatException('bad'));
  }

  void dispose() {
    _incoming.close();
    _link.close();
    _scan.close();
  }
}

class LinkedPeripheral implements BlePeripheralTransport {
  LinkedCentral? peer;
  final _incoming = StreamController<BleMessage>.broadcast();
  final _link = StreamController<BleLinkState>.broadcast();
  final _device = StreamController<String?>.broadcast();
  final List<BleMessage> sent = [];

  @override
  Future<void> startAdvertising() async {
    if (!_link.isClosed) _link.add(BleLinkState.advertising);
  }

  @override
  Future<void> stopAdvertising() async {
    if (!_link.isClosed) _link.add(BleLinkState.idle);
  }

  @override
  Stream<BleLinkState> get connectionState => _link.stream;

  @override
  Stream<String?> get connectedDeviceId => _device.stream;

  @override
  Future<void> send(BleMessage message) async {
    sent.add(message);
    peer?.deliver(message);
  }

  @override
  Stream<BleMessage> get incomingMessages => _incoming.stream;

  // test drivers
  void deliver(BleMessage m) {
    if (!_incoming.isClosed) _incoming.add(m);
  }

  void emitIncoming(BleMessage m) => deliver(m);

  /// Signals a customer is connected AND ready to receive (the OFFER trigger).
  /// Mirrors the real [BlePeripheralTransport] contract: `connectedDeviceId`
  /// fires only once the central has *subscribed* to notifications, never on
  /// the raw connection event — sending an OFFER before the CCCD subscribe
  /// completes silently drops it on real hardware (fixed in
  /// BlePeripheralTransportImpl._onSubscriptionChange).
  void onPayerConnected(String id) {
    if (!_link.isClosed) _link.add(BleLinkState.connected);
    if (!_device.isClosed) _device.add(id);
  }

  void onPayerDisconnected() {
    if (!_device.isClosed) _device.add(null);
  }

  void emitConnected(String id) => onPayerConnected(id);

  void emitMalformed() {
    if (!_incoming.isClosed) _incoming.addError(BleMessageFormatException('bad'));
  }

  void dispose() {
    _incoming.close();
    _link.close();
    _device.close();
  }
}

class LinkedFakeTransport {
  final LinkedCentral central = LinkedCentral();
  final LinkedPeripheral peripheral = LinkedPeripheral();

  LinkedFakeTransport() {
    central.peer = peripheral;
    peripheral.peer = central;
  }

  void dispose() {
    central.dispose();
    peripheral.dispose();
  }
}

/// Let queued broadcast-stream events and microtasks drain between steps.
Future<void> pump([int turns = 6]) async {
  for (var i = 0; i < turns; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
