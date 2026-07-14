import 'package:flutter_test/flutter_test.dart';
import 'package:offline_wallet/core/money.dart';
import 'package:offline_wallet/core/result.dart';

void main() {
  group('Money (ADR-4: integer paise, INR)', () {
    test('constructs from valid integer paise', () {
      final r = Money.fromPaise(500);
      expect(r.isOk, isTrue);
      final m = (r as Ok).value;
      expect(m.paise, 500);
      expect(m.currency, 'INR');
    });

    test('rejects negative amounts', () {
      expect(Money.fromPaise(-1).isErr, isTrue);
    });

    test('converts whole rupees to paise', () {
      final r = Money.fromRupees(5) as Ok;
      expect(r.value.paise, 5 * kPaisePerRupee);
    });

    test('adds without rounding error', () {
      final a = (Money.fromPaise(1) as Ok).value;
      final b = (Money.fromPaise(2) as Ok).value;
      expect(a.add(b).paise, 3);
    });

    test('subtract fails rather than going negative', () {
      final a = (Money.fromPaise(100) as Ok).value;
      final b = (Money.fromPaise(200) as Ok).value;
      expect(a.subtract(b).isErr, isTrue);
    });

    test('formats as INR rupees', () {
      expect((Money.fromPaise(500) as Ok).value.format(), '₹5.00');
    });
  });
}
