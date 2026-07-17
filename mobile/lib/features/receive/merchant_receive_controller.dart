import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/core/crypto/transfer_verifier.dart';
import 'package:offline_wallet/core/money.dart';
import 'package:offline_wallet/domain/ble_message.dart';
import 'package:offline_wallet/domain/ble_transport.dart';
import 'package:offline_wallet/domain/denominations.dart';
import 'package:offline_wallet/domain/merchant.dart';
import 'package:offline_wallet/domain/qr_codec.dart';
import 'package:offline_wallet/domain/token.dart';
import 'package:offline_wallet/domain/transfer.dart';
import 'package:offline_wallet/platform/ble/ble_permission_service.dart';

import 'ble_merchant_provider.dart';
import 'pending_settlement_provider.dart';

/// Stub merchant id for the backend-free BLE receive flow (real merchant
/// registration needs the backend, which is out of scope for Task 8). The QR
/// and the BLE OFFER both carry this same id + nonce so the payer can bind them.
const String kBleMerchantId = 'MER-LOCALDEMO01';

/// Merchant-side receive session state machine (the payee half of the offline
/// protocol). Distinct from the BLE *link* state.
enum MerchantReceiveStatus {
  idle,
  waiting, // advertising, showing QR, no payment yet
  receiving, // payer connected + accepted (ACK)
  verifying, // TOKEN_TRANSFER arrived, validating
  received, // validated + stored → Pending Settlement
  rejected, // validation failed / cancelled by us
  cancelled, // payer cancelled
}

class MerchantReceiveState {
  final MerchantReceiveStatus status;
  final String statusMessage;
  /// Null for an Open Cash session before a transfer arrives (no amount was
  /// pre-decided); set to the merchant's fixed amount for a Fixed Amount
  /// session, and updated to the actually-received amount once a transfer is
  /// accepted (§`_handleTransfer`).
  final int? amountPaise;
  final String qrData; // encoded merchant QR to display (empty until started)
  final List<Token> receivedTokens;
  final TransferRejectReason? reason;

  const MerchantReceiveState({
    required this.status,
    required this.statusMessage,
    this.amountPaise,
    this.qrData = '',
    this.receivedTokens = const [],
    this.reason,
  });

  /// Value received but not yet settled (FR-MER-02). Grows on a valid transfer.
  Money get pendingSettlement => sumDenominations(receivedTokens);
  int get receivedCount => receivedTokens.length;

  MerchantReceiveState copyWith({
    MerchantReceiveStatus? status,
    String? statusMessage,
    int? amountPaise,
    String? qrData,
    List<Token>? receivedTokens,
    TransferRejectReason? reason,
  }) =>
      MerchantReceiveState(
        status: status ?? this.status,
        statusMessage: statusMessage ?? this.statusMessage,
        amountPaise: amountPaise ?? this.amountPaise,
        qrData: qrData ?? this.qrData,
        receivedTokens: receivedTokens ?? this.receivedTokens,
        reason: reason ?? this.reason,
      );
}

/// Drives: advertise (+ show QR) → payer connects → send OFFER → receive
/// ACK + TOKEN_TRANSFER → validate → store tokens as Pending Settlement →
/// TRANSFER_COMPLETE. Rejects insufficient/mismatched/expired/malformed
/// transfers with a CANCEL, and is idempotent on a duplicate transfer for an
/// already-completed nonce (no double-credit).
class MerchantReceiveController extends StateNotifier<MerchantReceiveState> {
  final BlePeripheralTransport _transport;
  final BlePermissionService _permissions;
  final String _merchantId;

  /// Invoked once, when a transfer is accepted, with the stored tokens. The
  /// provider wires this to the pending-settlement store so the merchant can
  /// later redeem them from the Settlement screen (Task 9). Defaults to a
  /// no-op so existing unit tests can construct the controller directly.
  final void Function(List<Token> tokens)? _onTokensReceived;

  StreamSubscription<String?>? _deviceSub;
  StreamSubscription<BleMessage>? _msgSub;
  bool _started = false;
  bool _offerSent = false;
  String _nonce = '';
  int _ts = 0;
  String? _completedNonce; // set once a transfer is accepted (dedupe key)

  MerchantReceiveController({
    required BlePeripheralTransport transport,
    required BlePermissionService permissions,
    String merchantId = kBleMerchantId,
    void Function(List<Token> tokens)? onTokensReceived,
  })  : _transport = transport,
        _permissions = permissions,
        _merchantId = merchantId,
        _onTokensReceived = onTokensReceived,
        super(const MerchantReceiveState(
          status: MerchantReceiveStatus.idle,
          statusMessage: 'Enter an amount to receive',
        ));

  MerchantReceiveStatus get _status => state.status;

  /// Begin receiving. [amountPaise] fixes the requested amount (Fixed
  /// Amount); pass null for Open Cash — the QR/OFFER carry no amount, and
  /// whatever positive amount the payer's TOKEN_TRANSFER claims (verified
  /// against the tokens actually sent) is accepted. Mints a local QR, shows
  /// it, and starts advertising. Safe to call once.
  Future<void> start(int? amountPaise) async {
    if (_started) return;
    _started = true;

    _nonce = 'n-${DateTime.now().microsecondsSinceEpoch}';
    _ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final qr = encodeMerchantQr(QrPayload(
      v: 1,
      merchantId: _merchantId,
      nonce: _nonce,
      ts: _ts,
      amountPaise: amountPaise,
    ));
    state = state.copyWith(
      status: MerchantReceiveStatus.waiting,
      statusMessage: 'Waiting for customer…',
      amountPaise: amountPaise,
      qrData: qr,
    );

    final granted = await _permissions.requestBlePermissions();
    if (granted != true) {
      _rejectLocal(TransferRejectReason.internal, 'Bluetooth permission denied.');
      return;
    }

    _deviceSub = _transport.connectedDeviceId.listen(_onDevice);
    _msgSub = _transport.incomingMessages.listen(_onMessage, onError: _onMessageError);
    try {
      await _transport.startAdvertising();
    } catch (error) {
      final message =
          error is BleTransportException ? error.message : 'Could not start advertising.';
      _rejectLocal(TransferRejectReason.internal, message);
    }
  }

  void _onDevice(String? deviceId) {
    if (deviceId == null || _offerSent || _status != MerchantReceiveStatus.waiting) return;
    _offerSent = true;
    unawaited(_sendOffer());
  }

  Future<void> _sendOffer() async {
    final offer = PaymentOffer(
      amountPaise: state.amountPaise,
      merchantId: _merchantId,
      nonce: _nonce,
      ts: _ts,
    );
    await _trySend(BleMessage.offer(offer));
  }

  void _onMessage(BleMessage message) {
    switch (message.type) {
      case BleMessageType.ack:
        if (_status == MerchantReceiveStatus.waiting) {
          state = state.copyWith(
            status: MerchantReceiveStatus.receiving,
            statusMessage: 'Receiving payment…',
          );
        }
      case BleMessageType.tokenTransfer:
        _handleTransfer(message);
      case BleMessageType.cancel:
        _handleCancel(message);
      case BleMessageType.offer:
      case BleMessageType.transferComplete:
        break; // merchant never receives these
    }
  }

  void _onMessageError(Object error, StackTrace _) {
    if (_isTerminal) return;
    _reject(TransferRejectReason.malformed);
  }

  void _handleTransfer(BleMessage message) {
    unawaited(_handleTransferAsync(message));
  }

  Future<void> _handleTransferAsync(BleMessage message) async {
    // Idempotent duplicate: a re-sent transfer for an already-accepted nonce
    // gets the same TRANSFER_COMPLETE re-sent, with no second credit.
    if (_completedNonce != null) {
      unawaited(_trySend(BleMessage.transferComplete(
        TransferComplete(nonce: _completedNonce!, receivedCount: state.receivedCount),
      )));
      return;
    }
    if (_isTerminal) return;

    state = state.copyWith(
      status: MerchantReceiveStatus.verifying,
      statusMessage: 'Verifying…',
    );

    final TokenTransfer transfer;
    try {
      transfer = message.asTokenTransfer();
    } catch (_) {
      _reject(TransferRejectReason.malformed);
      return;
    }

    if (transfer.nonce != _nonce || transfer.merchantId != _merchantId) {
      _reject(TransferRejectReason.nonceMismatch);
      return;
    }
    if (transfer.tokens.length != transfer.tokenIds.length) {
      _reject(TransferRejectReason.malformed);
      return;
    }
    // Integrity: the claimed amount must equal the sum of the tokens actually
    // sent (true for both modes — no hidden value, D2 no-change).
    final sum = sumDenominations(transfer.tokens);
    if (transfer.amountPaise <= 0 || sum.paise != transfer.amountPaise) {
      _reject(TransferRejectReason.amountMismatch);
      return;
    }
    // Fixed Amount session: the claimed amount must also match what the
    // merchant pre-decided. Open Cash (state.amountPaise == null): any
    // positive, integrity-checked amount is accepted — the payer decides.
    final expected = state.amountPaise;
    if (expected != null && transfer.amountPaise != expected) {
      _reject(TransferRejectReason.amountMismatch);
      return;
    }
    final now = DateTime.now();
    if (transfer.tokens.any((t) => t.isExpired(now))) {
      _reject(TransferRejectReason.expiredToken);
      return;
    }

    // Owner-signed transfer proof (FR-PAY-04, PAYMENT_PROTOCOL.md §6.4 step 4):
    // the payer's signature must verify against the public key it presented,
    // over the exact fields carried in this transfer — any tamper (a
    // different amount, merchant, nonce, timestamp, token set, or a
    // substituted public key) invalidates it. This is the ownership proof;
    // whether that public key belongs to a device actually registered to
    // this payer's account is a connectivity-dependent check this merchant
    // cannot make offline (D3 "detect at settlement", not prevent here).
    final validSignature = await verifyTransferSignature(
      payload: transfer.signingPayload(),
      signatureHex: transfer.payerSignature,
      publicKeyHex: transfer.payerPublicKey,
    );
    if (!mounted || _isTerminal) return; // session ended while verifying
    if (!validSignature) {
      _reject(TransferRejectReason.invalidSignature);
      return;
    }

    // Accept: store as Pending Settlement (no settlement yet — Task 9).
    _completedNonce = transfer.nonce;
    final stored = transfer.tokens.map((t) => t.copyWithStatus(TokenStatus.redeemed)).toList();
    state = state.copyWith(
      status: MerchantReceiveStatus.received,
      statusMessage: 'Payment received',
      amountPaise: transfer.amountPaise, // Open Cash: now known, from the payer.
      receivedTokens: stored,
    );
    // Hand the received tokens to the pending-settlement store (Task 9) so the
    // merchant can redeem them at the backend from the Settlement screen.
    _onTokensReceived?.call(stored);
    unawaited(_trySend(BleMessage.transferComplete(
      TransferComplete(nonce: transfer.nonce, receivedCount: stored.length),
    )));
  }

  void _handleCancel(BleMessage message) {
    if (_isTerminal) return;
    TransferRejectReason reason;
    try {
      reason = message.asCancel().reason;
    } catch (_) {
      reason = TransferRejectReason.cancelled;
    }
    state = state.copyWith(
      status: MerchantReceiveStatus.cancelled,
      statusMessage: reason.message,
      reason: reason,
    );
  }

  void _reject(TransferRejectReason reason) {
    if (_isTerminal) return;
    unawaited(_trySend(BleMessage.cancel(CancelNotice(reason))));
    state = state.copyWith(
      status: MerchantReceiveStatus.rejected,
      statusMessage: reason.message,
      reason: reason,
    );
  }

  void _rejectLocal(TransferRejectReason reason, String message) {
    state = state.copyWith(
      status: MerchantReceiveStatus.rejected,
      statusMessage: message,
      reason: reason,
    );
  }

  bool get _isTerminal =>
      _status == MerchantReceiveStatus.received ||
      _status == MerchantReceiveStatus.rejected ||
      _status == MerchantReceiveStatus.cancelled;

  Future<void> _trySend(BleMessage message) async {
    try {
      await _transport.send(message);
    } catch (_) {/* best effort */}
  }

  Future<void> stop() async {
    await _transport.stopAdvertising();
    _teardown();
  }

  void _teardown() {
    _deviceSub?.cancel();
    _msgSub?.cancel();
    _deviceSub = null;
    _msgSub = null;
  }

  @override
  void dispose() {
    _teardown();
    unawaited(_transport.stopAdvertising());
    super.dispose();
  }
}

final merchantReceiveControllerProvider = StateNotifierProvider.autoDispose<
    MerchantReceiveController, MerchantReceiveState>((ref) {
  return MerchantReceiveController(
    transport: ref.watch(blePeripheralTransportProvider),
    permissions: ref.watch(blePeripheralPermissionServiceProvider),
    onTokensReceived: (tokens) =>
        ref.read(pendingSettlementProvider.notifier).addTokens(tokens),
  );
});
