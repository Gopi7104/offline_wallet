import 'package:flutter_test/flutter_test.dart';
import 'package:offline_wallet/domain/ble_transport.dart';

void main() {
  group('BleLinkStateMachine', () {
    test('starts idle', () {
      expect(BleLinkStateMachine().state, BleLinkState.idle);
    });

    test('walks the full customer (central) path', () {
      final machine = BleLinkStateMachine();
      machine.transition(BleLinkState.scanning);
      machine.transition(BleLinkState.connecting);
      machine.transition(BleLinkState.connected);
      machine.transition(BleLinkState.disconnecting);
      machine.transition(BleLinkState.idle);
      expect(machine.state, BleLinkState.idle);
    });

    test('walks the full merchant (peripheral) path', () {
      final machine = BleLinkStateMachine();
      machine.transition(BleLinkState.advertising);
      machine.transition(BleLinkState.connected);
      machine.transition(BleLinkState.advertising);
      machine.transition(BleLinkState.idle);
      expect(machine.state, BleLinkState.idle);
    });

    test('allows a dropped link to return straight to idle from connected', () {
      final machine = BleLinkStateMachine(BleLinkState.connected);
      expect(machine.canTransition(BleLinkState.idle), isTrue);
      machine.transition(BleLinkState.idle);
      expect(machine.state, BleLinkState.idle);
    });

    test('rejects an illegal transition (idle -> connected)', () {
      final machine = BleLinkStateMachine();
      expect(machine.canTransition(BleLinkState.connected), isFalse);
      expect(() => machine.transition(BleLinkState.connected), throwsStateError);
    });

    test('rejects an illegal transition (scanning -> advertising)', () {
      final machine = BleLinkStateMachine(BleLinkState.scanning);
      expect(machine.canTransition(BleLinkState.advertising), isFalse);
      expect(() => machine.transition(BleLinkState.advertising), throwsStateError);
    });

    test('a failed transition leaves state unchanged', () {
      final machine = BleLinkStateMachine();
      try {
        machine.transition(BleLinkState.connected);
      } catch (_) {
        // expected
      }
      expect(machine.state, BleLinkState.idle);
    });
  });
}
