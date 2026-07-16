import 'package:offline_wallet/core/money.dart';
import 'package:offline_wallet/core/result.dart';

import 'token.dart';

/// Fine denominations (design decision D2), in paise, largest first.
/// {1,2,5,10,20,50,100,200,500} INR. No change is ever given — the payer's
/// app assembles the exact amount from these (PAYMENT_PROTOCOL.md §10).
const List<int> kDenominationsPaise = [
  50000, // ₹500
  20000, // ₹200
  10000, // ₹100
  5000, // ₹50
  2000, // ₹20
  1000, // ₹10
  500, // ₹5
  200, // ₹2
  100, // ₹1
];

/// Sum a set of tokens' face values. `Money.add` can't underflow here (all
/// denominations are positive), so folding is safe.
Money sumDenominations(Iterable<Token> tokens) =>
    tokens.fold(Money.zero(), (acc, t) => acc.add(t.denomination));

/// Break an arbitrary paise amount into a denomination multiset (greedy,
/// largest-first). Every listed denomination divides all larger ones, so the
/// greedy decomposition is always exact for any non-negative whole-paise
/// amount that is a multiple of the smallest denomination (100 paise = ₹1).
/// Returns null if the amount can't be represented (e.g. not a whole rupee).
List<int>? mintBreakdown(int amountPaise) {
  if (amountPaise < 0) return null;
  final out = <int>[];
  var remaining = amountPaise;
  for (final denom in kDenominationsPaise) {
    while (remaining >= denom) {
      out.add(denom);
      remaining -= denom;
    }
  }
  return remaining == 0 ? out : null;
}

/// Choose an exact-amount subset of [available] tokens summing to [amountPaise]
/// (D2: exact amount, no change). Greedy largest-first over the tokens the
/// wallet actually holds — which, because every denomination divides the next,
/// finds an exact set whenever one exists across these canonical denominations.
/// Returns null if no exact subset exists (insufficient balance, or the held
/// denominations can't make exact change).
List<Token>? selectExact(int amountPaise, List<Token> available) {
  if (amountPaise <= 0) return null;
  final pool = [...available]
    ..sort((a, b) => b.denomination.paise.compareTo(a.denomination.paise));
  final chosen = <Token>[];
  var remaining = amountPaise;
  for (final token in pool) {
    if (remaining <= 0) break;
    if (token.denomination.paise <= remaining) {
      chosen.add(token);
      remaining -= token.denomination.paise;
    }
  }
  return remaining == 0 ? chosen : null;
}

/// Convenience: does the wallet hold enough total value to cover [amountPaise]?
/// Distinct from [selectExact] returning null due to denomination granularity.
bool hasSufficientBalance(int amountPaise, List<Token> available) {
  final total = sumDenominations(available);
  return switch (Money.fromPaise(amountPaise)) {
    Ok(:final value) => total.paise >= value.paise,
    Err() => false,
  };
}
