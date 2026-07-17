import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/core/crypto/device_keypair_store.dart';
import 'package:offline_wallet/domain/ble_message.dart';
import 'package:offline_wallet/domain/ble_transport.dart';
import 'package:offline_wallet/domain/denominations.dart';
import 'package:offline_wallet/domain/token.dart';
import 'package:offline_wallet/domain/transfer.dart';
import 'package:offline_wallet/features/wallet/wallet_provider.dart';
import 'package:offline_wallet/platform/ble/ble_permission_service.dart';

import 'ble_customer_provider.dart';

/// Customer-side payment session state machine (the payer half of the offline
/// protocol). Distinct from the BLE *link* state — this tracks the payment.
enum PaymentSessionStatus {
  idle,
  connecting,
  awaitingOffer,
  verifying,
  sending,
  awaitingComplete,
  success,
  failed,
  cancelled,
}

class PaymentSessionState {
  final PaymentSessionStatus status;
  final String statusMessage;
  final TransferRejectReason? reason; // set on failed/cancelled
  final int amountPaise;
  final int tokenCount; // tokens transferred (on success)

  const PaymentSessionState({
    required this.status,
    required this.statusMessage,
    required this.amountPaise,
    this.reason,
    this.tokenCount = 0,
  });

  bool get isTerminal =>
      status == PaymentSessionStatus.success ||
      status == PaymentSessionStatus.failed ||
      status == PaymentSessionStatus.cancelled;
}

/// Everything the payer already knows from the scanned QR: used to bind the
/// QR to the BLE OFFER (merchant id + nonce) and to display/validate the
/// amount. Value type so it can key a Riverpod `.family`.
class PaymentSessionParams {
  final String merchantId;
  final String nonce;
  final int amountPaise;

  const PaymentSessionParams({
    required this.merchantId,
    required this.nonce,
    required this.amountPaise,
  });

  @override
  bool operator ==(Object other) =>
      other is PaymentSessionParams &&
      other.merchantId == merchantId &&
      other.nonce == nonce &&
      other.amountPaise == amountPaise;

  @override
  int get hashCode => Object.hash(merchantId, nonce, amountPaise);
}

/// Drives: scan → connect → receive OFFER → verify + select exact tokens →
/// ACK + TOKEN_TRANSFER → await TRANSFER_COMPLETE → spend tokens. Tokens leave
/// the wallet only on a valid TRANSFER_COMPLETE (atomicity); any abort/reject/
/// disconnect retains them.
class PaymentSessionController extends StateNotifier<PaymentSessionState> {
  final BleCentralTransport _transport;
  final TokenWalletNotifier _tokenWallet;
  final BlePermissionService _permissions;
  final DeviceKeyPairStore _deviceKeys;
  final PaymentSessionParams _params;
  final Duration _connectTimeout;
  final Duration _stepTimeout;

  StreamSubscription<List<BleDiscoveredDevice>>? _scanSub;
  StreamSubscription<BleLinkState>? _linkSub;
  StreamSubscription<BleMessage>? _msgSub;
  Timer? _timer;
  bool _started = false;
  bool _connectAttempted = false;
  List<String> _selectedTokenIds = const [];

  PaymentSessionController({
    required BleCentralTransport transport,
    required TokenWalletNotifier tokenWallet,
    required BlePermissionService permissions,
    required DeviceKeyPairStore deviceKeys,
    required PaymentSessionParams params,
    Duration connectTimeout = const Duration(seconds: 20),
    Duration stepTimeout = const Duration(seconds: 20),
  })  : _transport = transport,
        _tokenWallet = tokenWallet,
        _permissions = permissions,
        _deviceKeys = deviceKeys,
        _params = params,
        _connectTimeout = connectTimeout,
        _stepTimeout = stepTimeout,
        super(PaymentSessionState(
          status: PaymentSessionStatus.idle,
          statusMessage: 'Preparing…',
          amountPaise: params.amountPaise,
        ));

  PaymentSessionStatus get _status => state.status;
  bool get _midSession =>
      _status == PaymentSessionStatus.awaitingOffer ||
      _status == PaymentSessionStatus.verifying ||
      _status == PaymentSessionStatus.sending ||
      _status == PaymentSessionStatus.awaitingComplete;

  /// Begin the session. Safe to call once.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    _set(PaymentSessionStatus.connecting, 'Connecting…');
    final granted = await _permissions.requestBlePermissions();
    if (granted != true) {
      _fail(TransferRejectReason.disconnected, sendCancel: false);
      return;
    }

    _linkSub = _transport.connectionState.listen(_onLink);
    _msgSub = _transport.incomingMessages.listen(_onMessage, onError: _onMessageError);

    _armTimer(_connectTimeout, TransferRejectReason.disconnected);
    _scanSub = _transport.scanForMerchants().listen(_onDevices);
  }

  void _onDevices(List<BleDiscoveredDevice> devices) {
    if (_connectAttempted || devices.isEmpty || state.isTerminal) return;
    _connectAttempted = true;
    unawaited(_connect(devices.first.id));
  }

  Future<void> _connect(String deviceId) async {
    try {
      await _transport.connect(deviceId);
    } catch (_) {
      _fail(TransferRejectReason.disconnected, sendCancel: false);
    }
  }

  void _onLink(BleLinkState link) {
    if (state.isTerminal) return;
    if (link == BleLinkState.connected && _status == PaymentSessionStatus.connecting) {
      _set(PaymentSessionStatus.awaitingOffer, 'Waiting for merchant…');
      _armTimer(_stepTimeout, TransferRejectReason.disconnected);
    } else if (link == BleLinkState.idle && _midSession) {
      _fail(TransferRejectReason.disconnected, sendCancel: false);
    }
  }

  void _onMessage(BleMessage message) {
    if (state.isTerminal) return;
    switch (message.type) {
      case BleMessageType.offer:
        _handleOffer(message);
      case BleMessageType.transferComplete:
        _handleComplete(message);
      case BleMessageType.cancel:
        _handleCancel(message);
      case BleMessageType.ack:
      case BleMessageType.tokenTransfer:
        break; // payer never receives these
    }
  }

  void _onMessageError(Object error, StackTrace _) {
    if (state.isTerminal) return;
    _fail(TransferRejectReason.malformed);
  }

  void _handleOffer(BleMessage message) {
    if (_status != PaymentSessionStatus.awaitingOffer) return;
    _timer?.cancel();
    _set(PaymentSessionStatus.verifying, 'Verifying…');

    final PaymentOffer offer;
    try {
      offer = message.asOffer();
    } catch (_) {
      _fail(TransferRejectReason.malformed);
      return;
    }

    // Bind the scanned QR to this BLE peer.
    if (offer.merchantId != _params.merchantId || offer.nonce != _params.nonce) {
      _fail(TransferRejectReason.nonceMismatch);
      return;
    }
    // Fixed Amount offer: must match what the payer already agreed to pay
    // (from the QR). Open Cash offer (offer.amountPaise == null): the
    // merchant pre-decided nothing, so the payer's own entered amount
    // (_params.amountPaise) is authoritative instead — nothing to compare here.
    if (offer.amountPaise != null && offer.amountPaise != _params.amountPaise) {
      _fail(TransferRejectReason.amountMismatch);
      return;
    }

    final amountPaise = _params.amountPaise;
    final tokens = _tokenWallet.state;
    if (!hasSufficientBalance(amountPaise, tokens)) {
      _fail(TransferRejectReason.insufficientBalance);
      return;
    }
    final selected = selectExact(amountPaise, tokens);
    if (selected == null) {
      _fail(TransferRejectReason.insufficientTokens);
      return;
    }

    _selectedTokenIds = selected.map((t) => t.id).toList();
    unawaited(_sendTransfer(offer, selected, amountPaise));
  }

  Future<void> _sendTransfer(PaymentOffer offer, List<Token> selected, int amountPaise) async {
    _set(PaymentSessionStatus.sending, 'Sending payment…');
    try {
      await _transport.send(BleMessage.ack(TransferAck(nonce: offer.nonce)));
      final payerPublicKey = await _deviceKeys.publicKeyHex();
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final payload = canonicalTransferPayload(
        v: kTransferProtocolVersion,
        tokenIds: _selectedTokenIds,
        // Always the payer's own resolved amount — for a Fixed Amount offer
        // this already equals offer.amountPaise (checked above); for Open
        // Cash, offer.amountPaise is null and this is the only amount there
        // is (PAYMENT_PROTOCOL.md's "amount == Σ denom" still holds — it's
        // just decided by the payer instead of the merchant).
        amountPaise: amountPaise,
        merchantId: offer.merchantId,
        nonce: offer.nonce,
        timestamp: timestamp,
        payerId: kCustomerAccountId,
        payerPublicKeyHex: payerPublicKey,
      );
      final signature = await _deviceKeys.sign(payload);
      final transfer = TokenTransfer(
        tokenIds: _selectedTokenIds,
        tokens: selected.map((t) => t.copyWithStatus(TokenStatus.inTransit)).toList(),
        amountPaise: amountPaise,
        merchantId: offer.merchantId,
        nonce: offer.nonce,
        timestamp: timestamp,
        payerId: kCustomerAccountId,
        payerPublicKey: payerPublicKey,
        payerSignature: signature,
      );
      await _transport.send(BleMessage.tokenTransfer(transfer));
      _set(PaymentSessionStatus.awaitingComplete, 'Waiting for confirmation…');
      _armTimer(_stepTimeout, TransferRejectReason.disconnected);
    } catch (_) {
      _fail(TransferRejectReason.disconnected, sendCancel: false);
    }
  }

  void _handleComplete(BleMessage message) {
    if (_status != PaymentSessionStatus.awaitingComplete) return;
    _timer?.cancel();
    // Atomic point-of-no-return: value leaves the wallet only now, exactly once.
    _tokenWallet.spend(_selectedTokenIds);
    state = PaymentSessionState(
      status: PaymentSessionStatus.success,
      statusMessage: 'Payment complete',
      amountPaise: _params.amountPaise,
      tokenCount: _selectedTokenIds.length,
    );
    _teardown(disconnect: true);
  }

  void _handleCancel(BleMessage message) {
    TransferRejectReason reason;
    try {
      reason = message.asCancel().reason;
    } catch (_) {
      reason = TransferRejectReason.internal;
    }
    // Merchant already aborted — don't echo a CANCEL; tokens were never spent.
    _fail(reason, sendCancel: false);
  }

  /// User-initiated cancel from the UI.
  Future<void> cancel() async {
    if (state.isTerminal) return;
    await _trySend(BleMessage.cancel(const CancelNotice(TransferRejectReason.cancelled)));
    state = PaymentSessionState(
      status: PaymentSessionStatus.cancelled,
      statusMessage: 'Cancelled',
      amountPaise: _params.amountPaise,
      reason: TransferRejectReason.cancelled,
    );
    _teardown(disconnect: true);
  }

  void _fail(TransferRejectReason reason, {bool sendCancel = true}) {
    if (state.isTerminal) return;
    if (sendCancel) unawaited(_trySend(BleMessage.cancel(CancelNotice(reason))));
    state = PaymentSessionState(
      status: PaymentSessionStatus.failed,
      statusMessage: reason.message,
      amountPaise: _params.amountPaise,
      reason: reason,
    );
    _teardown(disconnect: true);
  }

  Future<void> _trySend(BleMessage message) async {
    try {
      await _transport.send(message);
    } catch (_) {/* best effort — link may already be gone */}
  }

  void _armTimer(Duration d, TransferRejectReason onTimeout) {
    _timer?.cancel();
    _timer = Timer(d, () {
      if (!state.isTerminal) _fail(onTimeout, sendCancel: false);
    });
  }

  void _set(PaymentSessionStatus status, String message) {
    state = PaymentSessionState(
      status: status,
      statusMessage: message,
      amountPaise: _params.amountPaise,
    );
  }

  void _teardown({bool disconnect = false}) {
    _timer?.cancel();
    _scanSub?.cancel();
    _linkSub?.cancel();
    _msgSub?.cancel();
    _scanSub = null;
    _linkSub = null;
    _msgSub = null;
    // disconnect() no-ops if a device was never connected, so a session that
    // fails/times out during the scanning phase must also stopScan() itself —
    // otherwise the transport's link state stays stuck at `scanning` forever,
    // and the next payment attempt's scanForMerchants() throws (illegal
    // scanning -> scanning transition) instead of starting a fresh scan.
    unawaited(_transport.stopScan());
    if (disconnect) unawaited(_transport.disconnect());
  }

  @override
  void dispose() {
    _teardown(disconnect: true);
    super.dispose();
  }
}

final paymentSessionProvider = StateNotifierProvider.autoDispose
    .family<PaymentSessionController, PaymentSessionState, PaymentSessionParams>(
        (ref, params) {
  final controller = PaymentSessionController(
    transport: ref.watch(bleCentralTransportProvider),
    tokenWallet: ref.watch(tokenWalletProvider.notifier),
    permissions: ref.watch(blePermissionServiceProvider),
    deviceKeys: ref.watch(deviceKeyPairStoreProvider),
    params: params,
  );
  return controller;
});
