import 'package:flutter_test/flutter_test.dart';
import 'package:offline_wallet/platform/ble/ble_chunking.dart';

void main() {
  group('BleChunker + BleReassembler', () {
    test('round-trips a payload larger than one chunk', () {
      const chunker = BleChunker(chunkSize: 16);
      final payload = List.generate(100, (i) => 'x').join(); // 100 chars → 7 frames
      final frames = chunker.split(payload, 1);
      expect(frames.length, 7);

      final reassembler = BleReassembler();
      String? result;
      for (final f in frames) {
        result = reassembler.offer(f);
      }
      expect(result, payload);
    });

    test('single-frame message reassembles immediately', () {
      const chunker = BleChunker(chunkSize: 1000);
      final frames = chunker.split('{"type":"ACK"}', 2);
      expect(frames.length, 1);
      expect(BleReassembler().offer(frames.single), '{"type":"ACK"}');
    });

    test('returns null until the final frame arrives', () {
      const chunker = BleChunker(chunkSize: 4);
      final frames = chunker.split('abcdefgh', 3); // 2 frames
      final reassembler = BleReassembler();
      expect(reassembler.offer(frames[0]), isNull);
      expect(reassembler.offer(frames[1]), 'abcdefgh');
    });

    test('duplicate (msgId, seq) frames are ignored idempotently', () {
      const chunker = BleChunker(chunkSize: 4);
      final frames = chunker.split('abcdefgh', 4); // 2 frames
      final reassembler = BleReassembler();
      expect(reassembler.offer(frames[0]), isNull);
      expect(reassembler.offer(frames[0]), isNull); // duplicate — still waiting
      expect(reassembler.offer(frames[1]), 'abcdefgh');
    });

    test('interleaved messages reassemble independently by msgId', () {
      const chunker = BleChunker(chunkSize: 4);
      final a = chunker.split('aaaabbbb', 1);
      final b = chunker.split('ccccdddd', 2);
      final r = BleReassembler();
      expect(r.offer(a[0]), isNull);
      expect(r.offer(b[0]), isNull);
      expect(r.offer(a[1]), 'aaaabbbb');
      expect(r.offer(b[1]), 'ccccdddd');
    });

    test('non-frame input throws FormatException', () {
      expect(() => BleReassembler().offer('{"not":"a frame"}'), throwsFormatException);
    });

    test('isFrame recognizes our frames', () {
      final frame = const BleChunker().split('hello', 9).single;
      expect(BleChunker.isFrame(frame), isTrue);
      expect(BleChunker.isFrame('{"type":"OFFER"}'), isFalse);
    });
  });
}
