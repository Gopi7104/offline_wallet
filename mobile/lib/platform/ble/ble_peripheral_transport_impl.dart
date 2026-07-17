import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

import '../../domain/ble_message.dart';
import '../../domain/ble_transport.dart';
import 'ble_chunking.dart';
import 'ble_uuids.dart';

/// Merchant role adapter (ARCHITECTURE.md §6.1 `platform/ble`).
/// Concrete `universal_ble` implementation of [BlePeripheralTransport] —
/// the only class in the app that imports `universal_ble` for the
/// peripheral/GATT-server role.
///
/// This is a dumb pipe: it only frames/deframes JSON over the characteristic.
/// The PING/PONG reply behavior is demo/protocol logic and lives one layer up,
/// in `BleMerchantController` (`features/receive/ble_merchant_provider.dart`).
class BlePeripheralTransportImpl implements BlePeripheralTransport {
  final _stateMachine = BleLinkStateMachine();
  final _stateController = StreamController<BleLinkState>.broadcast();
  final _connectedDeviceController = StreamController<String?>.broadcast();
  final _messageController = StreamController<BleMessage>.broadcast();

  final _chunker = const BleChunker();
  final _reassembler = BleReassembler();
  int _msgId = 0;

  String? _connectedDeviceId;
  // True once the connected central has enabled notifications on our
  // characteristic — the only moment it is safe to push the OFFER. Emitting a
  // notification before the CCCD subscribe completes silently drops it (there
  // is no OFFER retransmission), so the offer trigger is gated on this, NOT on
  // the raw connection event.
  bool _subscribed = false;

  BlePeripheralTransportImpl() {
    UniversalBlePeripheral.connectionStateStream.listen(_onConnectionChange);
    UniversalBlePeripheral.characteristicSubscriptionStream.listen(_onSubscriptionChange);
    UniversalBlePeripheral.setWriteRequestHandlers(_onWriteRequest);
  }

  void _emitState(BleLinkState state) {
    _stateMachine.transition(state);
    _stateController.add(state);
  }

  @override
  Future<void> startAdvertising() async {
    // Check the radio itself before touching the GATT server: with Bluetooth
    // off, native `openGattServer()` fails with an opaque platform error (logs
    // as "Fail to get GATT Server connection") that gives the receive
    // controller nothing to show the merchant beyond "Could not start
    // advertising." — indistinguishable from a real bug. Surface the actual
    // cause instead.
    final readiness = await UniversalBlePeripheral.getAvailabilityState();
    switch (readiness) {
      case PeripheralReadinessState.bluetoothOff:
        throw BleTransportException('Bluetooth is turned off. Turn it on to receive payments.');
      case PeripheralReadinessState.unauthorized:
        throw BleTransportException('Bluetooth permission is required to receive payments.');
      case PeripheralReadinessState.unsupported:
        // On Android this can mean genuinely-unsupported hardware, but the
        // native check (adapter.isMultipleAdvertisementSupported()) also
        // reports UNSUPPORTED whenever Bluetooth is simply off, on many
        // chipsets — so don't tell the merchant their device is incapable
        // when the real fix is almost always just turning Bluetooth on.
        throw BleTransportException(
          'Could not start Bluetooth advertising. Make sure Bluetooth is turned on and try again.',
        );
      case PeripheralReadinessState.ready:
      case PeripheralReadinessState.unknown:
        break;
    }

    await UniversalBlePeripheral.addService(
      BlePeripheralService(
        uuid: BleUuids.service,
        characteristics: [
          BlePeripheralCharacteristic(
            uuid: BleUuids.messageCharacteristic,
            properties: const [
              CharacteristicProperty.write,
              CharacteristicProperty.writeWithoutResponse,
              CharacteristicProperty.read,
              CharacteristicProperty.notify,
            ],
            permissions: const [
              PeripheralAttributePermission.writeable,
              PeripheralAttributePermission.readable,
            ],
          ),
        ],
      ),
    );

    // A 128-bit service UUID (18 bytes) plus the local name (15 bytes) plus the
    // flags overflow the 31-byte legacy advertisement, so Android rejects the
    // request asynchronously with ADVERTISE_FAILED_DATA_TOO_LARGE and nothing
    // is ever broadcast. Push the service UUID into the *scan response* (its own
    // 31-byte budget) so the primary packet carries only the name and fits.
    final config = PeripheralPlatformConfig(
      android: PeripheralAndroidOptions(addServicesInScanResponse: true),
    );

    // startAdvertising() resolves before the adapter reports success/failure, so
    // await the advertising-state callback to turn an async failure into a real
    // error the receive controller can surface (instead of "Waiting…" forever).
    final started = _awaitAdvertisingStarted();
    await UniversalBlePeripheral.startAdvertising(
      services: [BleUuids.service],
      localName: BleUuids.merchantLocalName,
      platformConfig: config,
    );
    await started;
    _emitState(BleLinkState.advertising);
  }

  /// Resolve when the adapter confirms advertising started; throw if it reports
  /// an error. Falls back to success after a short grace period on platforms
  /// that don't emit an advertising-state event, so this never hangs the caller.
  Future<void> _awaitAdvertisingStarted() {
    final completer = Completer<void>();
    late final StreamSubscription<BlePeripheralAdvertisingStateChanged> sub;
    final timer = Timer(const Duration(seconds: 3), () {
      if (!completer.isCompleted) completer.complete();
    });
    sub = UniversalBlePeripheral.advertisingStateStream.listen((event) {
      if (completer.isCompleted) return;
      if (event.state == PeripheralAdvertisingState.advertising) {
        completer.complete();
      } else if (event.state == PeripheralAdvertisingState.error) {
        completer.completeError(
          BleTransportException('Advertising failed: ${event.error ?? 'unknown'}'),
        );
      }
    });
    return completer.future.whenComplete(() {
      timer.cancel();
      sub.cancel();
    });
  }

  @override
  Future<void> stopAdvertising() async {
    await UniversalBlePeripheral.stopAdvertising();
    if (_stateMachine.canTransition(BleLinkState.idle)) {
      _emitState(BleLinkState.idle);
    }
  }

  void _onConnectionChange(BlePeripheralConnectionStateChanged event) {
    if (event.connected) {
      // Remember the peer so send() has a target, but do NOT trigger the OFFER
      // yet — wait for the central to subscribe (see _onSubscriptionChange).
      _connectedDeviceId = event.deviceId;
      if (_stateMachine.canTransition(BleLinkState.connected)) {
        _emitState(BleLinkState.connected);
      }
    } else {
      _connectedDeviceId = null;
      _subscribed = false;
      _connectedDeviceController.add(null);
      if (_stateMachine.canTransition(BleLinkState.advertising)) {
        _emitState(BleLinkState.advertising);
      }
    }
  }

  void _onSubscriptionChange(BlePeripheralCharacteristicSubscriptionChanged event) {
    if (event.characteristicId.toLowerCase() !=
        BleUuids.messageCharacteristic.toLowerCase()) {
      return;
    }
    if (event.isSubscribed) {
      // The central is now listening for notifications: it is finally safe to
      // push the OFFER. This is the signal the receive controller reacts to.
      _connectedDeviceId = event.deviceId;
      if (!_subscribed) {
        _subscribed = true;
        _connectedDeviceController.add(_connectedDeviceId);
      }
    } else {
      _subscribed = false;
    }
  }

  PeripheralWriteRequestResult? _onWriteRequest(
    String deviceId,
    String characteristicId,
    int offset,
    Uint8List? value,
  ) {
    if (characteristicId != BleUuids.messageCharacteristic || value == null) {
      return null;
    }
    try {
      final payload = _reassembler.offer(utf8.decode(value));
      if (payload != null) _messageController.add(BleMessage.decode(payload));
    } catch (e) {
      // Surface a malformed/corrupt payload to the receive session (Task 8),
      // instead of Task 7's silent drop, so it can reject cleanly.
      _messageController.addError(BleMessageFormatException('$e'));
    }
    return null;
  }

  @override
  Future<void> send(BleMessage message) async {
    final deviceId = _connectedDeviceId;
    if (deviceId == null) {
      throw BleTransportException('No connected customer to send to.');
    }
    final frames = _chunker.split(message.encode(), _msgId++);
    for (final frame in frames) {
      await UniversalBlePeripheral.updateCharacteristicValue(
        characteristicId: BleUuids.messageCharacteristic,
        value: Uint8List.fromList(utf8.encode(frame)),
        deviceId: deviceId,
      );
    }
  }

  @override
  Stream<BleLinkState> get connectionState => _stateController.stream;

  @override
  Stream<String?> get connectedDeviceId => _connectedDeviceController.stream;

  @override
  Stream<BleMessage> get incomingMessages => _messageController.stream;
}
