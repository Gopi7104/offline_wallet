import 'dart:convert';

/// App-level fragmentation for BLE (PAYMENT_PROTOCOL.md §6.1). A single GATT
/// write / notification is capped at one ATT MTU (~20 bytes unnegotiated, up to
/// ~512 negotiated). A TOKEN_TRANSFER carrying several tokens easily exceeds
/// that, so messages are split into JSON frames that each fit in one packet and
/// reassembled on the far side. This is transport-only: it frames/deframes the
/// opaque JSON `BleMessage.encode()` string and never inspects its contents.
///
/// Frame shape (compact keys so the header overhead is tiny):
///   {"__c": <msgId>, "i": <seq>, "n": <total>, "d": "<chunk>"}
///
/// A single-frame message is still a valid frame (`n == 1`). Re-sent frames
/// with an already-seen (msgId, seq) are ignored (idempotent reassembly).
class BleChunker {
  /// Max UTF-8 bytes of the payload substring carried per frame. Kept small so
  /// a whole frame (header + data) stays within a conservatively-negotiated
  /// ATT MTU. Tunable; see the MTU-negotiation TODO in the plan.
  final int chunkSize;

  const BleChunker({this.chunkSize = 160});

  /// Split [payload] into ordered frame strings tagged with [msgId].
  List<String> split(String payload, int msgId) {
    final units = payload.codeUnits; // payload is JSON (ASCII-safe) from jsonEncode
    final total = units.isEmpty ? 1 : (units.length + chunkSize - 1) ~/ chunkSize;
    final frames = <String>[];
    for (var seq = 0; seq < total; seq++) {
      final start = seq * chunkSize;
      final end = (start + chunkSize) < units.length ? start + chunkSize : units.length;
      final slice = units.isEmpty ? '' : String.fromCharCodes(units.sublist(start, end));
      frames.add(jsonEncode({'__c': msgId, 'i': seq, 'n': total, 'd': slice}));
    }
    return frames;
  }

  /// Is [raw] one of our chunk frames (vs. some other JSON)? Used by the
  /// reassembler; exposed for tests.
  static bool isFrame(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map && decoded.containsKey('__c') && decoded.containsKey('d');
    } catch (_) {
      return false;
    }
  }
}

/// Reassembles frames produced by [BleChunker] back into the original payload.
/// One instance per peer/link. Thread a frame in with [offer]; it returns the
/// full payload once the final missing frame arrives, else null.
class BleReassembler {
  final Map<int, _Pending> _pending = {};

  /// Feed one received frame. Returns the reassembled payload when a message is
  /// complete, or null if more frames are still expected. Throws
  /// [FormatException] if [raw] isn't a recognizable frame.
  String? offer(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map || !decoded.containsKey('__c')) {
      throw const FormatException('Not a BLE chunk frame');
    }
    final msgId = decoded['__c'] as int;
    final seq = decoded['i'] as int;
    final total = decoded['n'] as int;
    final data = decoded['d'] as String? ?? '';

    final pending = _pending.putIfAbsent(msgId, () => _Pending(total));
    pending.parts[seq] = data; // duplicate (msgId, seq) simply overwrites — idempotent

    if (pending.parts.length < pending.total) return null;

    final buffer = StringBuffer();
    for (var i = 0; i < pending.total; i++) {
      buffer.write(pending.parts[i] ?? '');
    }
    _pending.remove(msgId);
    return buffer.toString();
  }
}

class _Pending {
  final int total;
  final Map<int, String> parts = {};
  _Pending(this.total);
}
