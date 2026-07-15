import 'package:flutter_test/flutter_test.dart';
import 'package:offline_wallet/core/money.dart';
import 'package:offline_wallet/core/result.dart';
import 'package:offline_wallet/domain/denominations.dart';
import 'package:offline_wallet/domain/token.dart';

Money _money(int paise) => switch (Money.fromPaise(paise)) {
      Ok(:final value) => value,
      Err() => Money.zero(),
    };

Token _token(String id, int denomPaise) => Token(
      id: id,
      denomination: _money(denomPaise),
      ownerId: 'owner',
      issuedAt: DateTime(2026, 1, 1),
      expiry: DateTime(2026, 12, 31),
      status: TokenStatus.inWallet,
      bankSignature: 'sig',
    );

void main() {
  group('mintBreakdown', () {
    test('greedy largest-first for a mixed amount (₹278 = 200+50+20+5+2+1)', () {
      expect(mintBreakdown(27800), [20000, 5000, 2000, 500, 200, 100]);
    });

    test('exact single denomination', () {
      expect(mintBreakdown(50000), [50000]);
    });

    test('zero → empty breakdown', () {
      expect(mintBreakdown(0), <int>[]);
    });

    test('non-whole-rupee (e.g. 150 paise) is unrepresentable → null', () {
      expect(mintBreakdown(150), isNull);
    });
  });

  group('selectExact', () {
    test('picks an exact subset when the wallet can make the amount', () {
      final wallet = [_token('a', 20000), _token('b', 5000), _token('c', 5000)];
      final chosen = selectExact(25000, wallet);
      expect(chosen, isNotNull);
      expect(sumDenominations(chosen!).paise, 25000);
    });

    test('returns null when total is insufficient', () {
      final wallet = [_token('a', 10000)];
      expect(selectExact(25000, wallet), isNull);
    });

    test('returns null when denominations cannot make exact change', () {
      // Holds only a ₹500 token but needs ₹200 — no change is given (D2).
      final wallet = [_token('a', 50000)];
      expect(selectExact(20000, wallet), isNull);
    });

    test('greedy uses larger tokens first (min token count)', () {
      final wallet = [
        _token('a', 10000),
        _token('b', 10000),
        _token('c', 5000),
        _token('d', 5000),
      ];
      final chosen = selectExact(15000, wallet)!;
      expect(sumDenominations(chosen).paise, 15000);
      expect(chosen.length, 2); // 100 + 50, not 50+50+50
      expect(chosen.first.denomination.paise, 10000);
    });
  });

  group('hasSufficientBalance', () {
    test('true when total ≥ amount even if exact change is impossible', () {
      final wallet = [_token('a', 50000)];
      expect(hasSufficientBalance(20000, wallet), isTrue);
      expect(selectExact(20000, wallet), isNull); // distinct concerns
    });

    test('false when total < amount', () {
      expect(hasSufficientBalance(60000, [_token('a', 50000)]), isFalse);
    });
  });

  group('sumDenominations', () {
    test('sums token face values', () {
      expect(sumDenominations([_token('a', 20000), _token('b', 5000)]).paise, 25000);
      expect(sumDenominations(const []).paise, 0);
    });
  });
}
