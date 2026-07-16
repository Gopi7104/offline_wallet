import 'package:flutter_test/flutter_test.dart';
import 'package:offline_wallet/domain/ble_message.dart';
import 'package:offline_wallet/domain/transfer.dart';

void main() {
  group('BleMessage (Task 8 protocol)', () {
    test('OFFER round-trips through JSON with its body', () {
      final msg = BleMessage.offer(const PaymentOffer(
        amountPaise: 25000,
        merchantId: 'MER-1',
        nonce: 'n-abc',
        ts: 1752403920,
      ));
      final decoded = BleMessage.decode(msg.encode());
      expect(decoded.type, BleMessageType.offer);
      final offer = decoded.asOffer();
      expect(offer.amountPaise, 25000);
      expect(offer.merchantId, 'MER-1');
      expect(offer.nonce, 'n-abc');
    });

    test('ACK / TRANSFER_COMPLETE / CANCEL round-trip', () {
      final ack = BleMessage.decode(BleMessage.ack(const TransferAck(nonce: 'n1')).encode());
      expect(ack.type, BleMessageType.ack);
      expect(ack.asAck().nonce, 'n1');

      final complete = BleMessage.decode(
          BleMessage.transferComplete(const TransferComplete(nonce: 'n1', receivedCount: 3)).encode());
      expect(complete.asTransferComplete().receivedCount, 3);

      final cancel = BleMessage.decode(
          BleMessage.cancel(const CancelNotice(TransferRejectReason.insufficientBalance)).encode());
      expect(cancel.asCancel().reason, TransferRejectReason.insufficientBalance);
    });

    test('wire type strings are SCREAMING_SNAKE_CASE', () {
      expect(BleMessageType.tokenTransfer.wireValue, 'TOKEN_TRANSFER');
      expect(BleMessageType.transferComplete.wireValue, 'TRANSFER_COMPLETE');
      expect(BleMessageType.offer.wireValue, 'OFFER');
    });

    test('unknown type throws BleMessageFormatException', () {
      expect(() => BleMessage.decode('{"type":"PING","body":{}}'),
          throwsA(isA<BleMessageFormatException>()));
    });

    test('invalid JSON / missing type throws', () {
      expect(() => BleMessage.decode('not json'), throwsA(isA<BleMessageFormatException>()));
      expect(() => BleMessage.decode('{"body":{}}'), throwsA(isA<BleMessageFormatException>()));
    });

    test('asserting the wrong typed accessor throws', () {
      final ack = BleMessage.ack(const TransferAck(nonce: 'n1'));
      expect(() => ack.asOffer(), throwsA(isA<BleMessageFormatException>()));
    });
  });
}
