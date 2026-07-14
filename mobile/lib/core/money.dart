import 'errors.dart';
import 'result.dart';

/// Money — foundational value object (ARCHITECTURE.md §4.2, ADR-4).
///
/// Amounts are integer **paise** (₹1 = 100 paise), never floats, and currency
/// is INR only (NFR-LEG-03). Immutable. Kept in sync with the backend
/// `shared/money.ts` so the wire contract has one meaning of "amount".
const String kCurrency = 'INR';
const int kPaisePerRupee = 100;

class Money {
  final int paise;
  final String currency;

  const Money._(this.paise, this.currency);

  static Result<Money, InvariantViolation> fromPaise(int paise) {
    if (paise < 0) {
      return Err(InvariantViolation('Money.paise must be non-negative, got $paise'));
    }
    return Ok(Money._(paise, kCurrency));
  }

  static Result<Money, InvariantViolation> fromRupees(int rupees) =>
      fromPaise(rupees * kPaisePerRupee);

  static Money zero() => const Money._(0, kCurrency);

  Money add(Money other) => Money._(paise + other.paise, kCurrency);

  Result<Money, InvariantViolation> subtract(Money other) =>
      fromPaise(paise - other.paise);

  bool get isZero => paise == 0;

  /// Human-readable, e.g. "₹5.00". Presentation only.
  String format() => '₹${(paise / kPaisePerRupee).toStringAsFixed(2)}';

  @override
  bool operator ==(Object other) =>
      other is Money && other.paise == paise && other.currency == currency;

  @override
  int get hashCode => Object.hash(paise, currency);
}
