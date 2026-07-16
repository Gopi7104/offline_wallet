import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/core/money.dart';
import 'package:offline_wallet/domain/denominations.dart';
import 'package:offline_wallet/domain/settlement.dart';
import 'package:offline_wallet/domain/token.dart';

/// Merchant's settlement buckets held across screens (FR-MER-02). Received
/// tokens sit in [pending] (received offline over BLE, not yet settled); on a
/// successful settlement the credited value moves to [settled].
///
/// This is the app-side projection for the demo: the receive flow is
/// backend-free, so the merchant accumulates received tokens locally, then
/// redeems them at the backend from the Settlement screen. The backend remains
/// authoritative for double-spend detection and the ledger.
class PendingSettlementState {
  final List<Token> pending;
  final Money settled;

  const PendingSettlementState({this.pending = const [], required this.settled});

  factory PendingSettlementState.initial() =>
      PendingSettlementState(pending: const [], settled: Money.zero());

  Money get pendingAmount => sumDenominations(pending);
  int get pendingCount => pending.length;
  bool get hasPending => pending.isNotEmpty;

  PendingSettlementState copyWith({List<Token>? pending, Money? settled}) =>
      PendingSettlementState(
        pending: pending ?? this.pending,
        settled: settled ?? this.settled,
      );
}

class PendingSettlementNotifier extends StateNotifier<PendingSettlementState> {
  PendingSettlementNotifier() : super(PendingSettlementState.initial());

  /// Add tokens received over BLE to the pending bucket (idempotent by token
  /// id — a re-added token is not counted twice).
  void addTokens(List<Token> tokens) {
    if (tokens.isEmpty) return;
    final existing = state.pending.map((t) => t.id).toSet();
    final fresh = tokens.where((t) => !existing.contains(t.id)).toList();
    if (fresh.isEmpty) return;
    state = state.copyWith(pending: [...state.pending, ...fresh]);
  }

  /// Apply a settlement outcome: credit the accepted amount to [settled] and
  /// clear the pending bucket (the tokens have been redeemed / accounted for).
  void markSettled(SettlementResult result) {
    state = PendingSettlementState(
      pending: const [],
      settled: state.settled.add(result.creditedAmount),
    );
  }

  /// Test/reset helper.
  void reset() => state = PendingSettlementState.initial();
}

final pendingSettlementProvider =
    StateNotifierProvider<PendingSettlementNotifier, PendingSettlementState>(
  (ref) => PendingSettlementNotifier(),
);
