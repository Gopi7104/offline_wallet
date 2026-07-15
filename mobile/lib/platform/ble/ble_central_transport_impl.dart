import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

import '../../domain/ble_message.dart';
import '../../domain/ble_transport.dart';
import 'ble_chunking.dart';
import 'ble_uuids.dart';

/// Customer/payer role adapter (ARCHITECTURE.md §6.1 `platform/ble`).
/// Concrete `universal_ble` implementation of [BleCentralTransport] — the
/// only class in the app that imports `universal_ble` for the central role.
class BleCentralTransportImpl implements BleCentralTransport {
  final _stateMachine = BleLinkStateMachine();
  final _stateController = StreamController<BleLinkState>.broadcast();
  final _messageController = StreamController<BleMessage>.broadcast();
  final _scanController = StreamController<List<BleDiscoveredDevice>>.broadcast();
  final Map<String, BleDevice> _discovered = {};

  // Fragmentation: a TOKEN_TRANSFER exceeds one ATT MTU, so messages are split
  // into frames on send and rebuilt on receive (transport-only, see BleChunker).
  final _chunker = const BleChunker();
  final _reassembler = BleReassembler();
  int _msgId = 0;

  StreamSubscription<BleDevice>? _scanSub;
  StreamSubscription<bool>? _connectionSub;
  StreamSubscription<Uint8List>? _valueSub;
  BleDevice? _connectedDevice;
  BleCharacteristic? _messageCharacteristic;

  void _emitState(BleLinkState state) {
    _stateMachine.transition(state);
    _stateController.add(state);
  }

  @override
  Stream<List<BleDiscoveredDevice>> scanForMerchants() {
    _discovered.clear();
    _emitState(BleLinkState.scanning);
    unawaited(_startScan());
    return _scanController.stream;
  }

  Future<void> _startScan() async {
    _scanSub = UniversalBle.scanStream.listen((device) {
      _discovered[device.deviceId] = device;
      _scanController.add(_discovered.values
          .map((d) => BleDiscoveredDevice(
                id: d.deviceId,
                name: (d.name?.isNotEmpty ?? false) ? d.name! : d.deviceId,
                rssi: d.rssi ?? 0,
              ))
          .toList(growable: false));
    });
    await UniversalBle.startScan(scanFilter: ScanFilter(withServices: [BleUuids.service]));
  }

  @override
  Future<void> stopScan() async {
    await UniversalBle.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
    if (_stateMachine.state == BleLinkState.scanning) {
      _emitState(BleLinkState.idle);
    }
  }

  @override
  Future<void> connect(String deviceId) async {
    await stopScan();
    final device = _discovered[deviceId];
    if (device == null) {
      throw BleTransportException('Unknown device: $deviceId');
    }
    _emitState(BleLinkState.connecting);
    try {
      await device.connect();
      _connectedDevice = device;
      _connectionSub = device.connectionStream.listen(_onConnectionChange);

      // Raise the ATT MTU before any exchange. The default is 23 bytes (~20
      // usable), but a single OFFER/TOKEN_TRANSFER frame is ~190 bytes, so at
      // the default MTU every notification and write is truncated and the
      // reassembler never completes. universal_ble does not auto-negotiate, so
      // request it explicitly (best-effort — a peer may grant less, and some
      // platforms ignore it, in which case the connection keeps its default).
      try {
        await UniversalBle.requestMtu(deviceId, 247);
      } catch (_) {
        // Non-fatal: proceed with whatever MTU the link negotiated.
      }

      final services = await device.discoverServices();
      final service = services.firstWhere(
        (s) => s.uuid.toLowerCase() == BleUuids.service.toLowerCase(),
        orElse: () => throw BleTransportException('Merchant service not found.'),
      );
      _messageCharacteristic = service.characteristics.firstWhere(
        (c) => c.uuid.toLowerCase() == BleUuids.messageCharacteristic.toLowerCase(),
        orElse: () => throw BleTransportException('Merchant characteristic not found.'),
      );
      await _messageCharacteristic!.notifications.subscribe();
      _valueSub = _messageCharacteristic!.onValueReceived.listen(_onValueReceived);

      _emitState(BleLinkState.connected);
    } catch (e) {
      _connectedDevice = null;
      _messageCharacteristic = null;
      if (_stateMachine.canTransition(BleLinkState.idle)) {
        _emitState(BleLinkState.idle);
      }
      throw BleTransportException('Failed to connect: $e');
    }
  }

  void _onConnectionChange(bool isConnected) {
    if (isConnected) return;
    _connectedDevice = null;
    _messageCharacteristic = null;
    if (_stateMachine.state != BleLinkState.idle && _stateMachine.canTransition(BleLinkState.idle)) {
      _emitState(BleLinkState.idle);
    }
  }

  void _onValueReceived(Uint8List value) {
    try {
      final payload = _reassembler.offer(utf8.decode(value));
      if (payload == null) return; // more frames still expected
      _messageController.add(BleMessage.decode(payload));
    } catch (e) {
      // Surface a malformed/corrupt payload to the session (Task 8), instead of
      // Task 7's silent drop, so it can abort cleanly rather than hang.
      _messageController.addError(BleMessageFormatException('$e'));
    }
  }

  @override
  Future<void> disconnect() async {
    final device = _connectedDevice;
    if (device == null) return;
    if (_stateMachine.canTransition(BleLinkState.disconnecting)) {
      _emitState(BleLinkState.disconnecting);
    }
    await _valueSub?.cancel();
    await _connectionSub?.cancel();
    await device.disconnect();
    _connectedDevice = null;
    _messageCharacteristic = null;
    if (_stateMachine.canTransition(BleLinkState.idle)) {
      _emitState(BleLinkState.idle);
    }
  }

  @override
  Future<void> send(BleMessage message) async {
    final characteristic = _messageCharacteristic;
    if (characteristic == null) {
      throw BleTransportException('Not connected to a merchant.');
    }
    final frames = _chunker.split(message.encode(), _msgId++);
    for (final frame in frames) {
      await characteristic.write(utf8.encode(frame), withResponse: false);
    }
  }

  @override
  Stream<BleLinkState> get connectionState => _stateController.stream;

  @override
  Stream<BleMessage> get incomingMessages => _messageController.stream;
}
