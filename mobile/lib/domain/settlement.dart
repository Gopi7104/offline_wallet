import 'package:offline_wallet/core/money.dart';
import 'token.dart';

/// Overall settlement outcome, mirroring the backend `SettlementStatus`
/// (ARCHITECTURE.md §5.6):
///  - success  : every token accepted and credited.
///  - partial  : some accepted, some rejected/duplicated.
///  - rejected : nothing credited (e.g. a repeat settlement of spent tokens).
enum SettlementStatus {
  success,
  partial,
  rejected;

  static SettlementStatus fromWire(String value) => switch (value) {
        'SUCCESS' => SettlementStatus.success,
        'PARTIAL' => SettlementStatus.partial,
        _ => SettlementStatus.rejected,
      };
}

/// SettlementResult — the merchant-facing summary of one settlement (Task 9).
/// Immutable. Counts are cardinalities; [creditedAmount] is the sum of the
/// accepted tokens' face values.
class SettlementResult {
  final String settlementId;
  final int accepted;
  final int rejected;
  final int duplicates;
  final Money creditedAmount;
  final String ledgerId;
  final SettlementStatus status;

  const SettlementResult({
    required this.settlementId,
    required this.accepted,
    required this.rejected,
    required this.duplicates,
    required this.creditedAmount,
    required this.ledgerId,
    required this.status,
  });

  bool get hasDuplicates => duplicates > 0;
}

/// Why a settlement failed at the request level (distinct from per-token
/// rejections, which come back inside a [SettlementResult]). Drives which
/// Material dialog the merchant sees.
enum SettlementErrorKind {
  unknownMerchant,
  malformedPayload,
  emptySettlement,
  network,
  unknown;

  static SettlementErrorKind fromCode(String? code) => switch (code) {
        'UNKNOWN_MERCHANT' => SettlementErrorKind.unknownMerchant,
        'MALFORMED_PAYLOAD' => SettlementErrorKind.malformedPayload,
        'EMPTY_SETTLEMENT' => SettlementErrorKind.emptySettlement,
        _ => SettlementErrorKind.unknown,
      };

  /// User-facing sentence for a Material dialog.
  String get message => switch (this) {
        unknownMerchant =>
          'This merchant is not registered with the server. Enable Merchant Mode online and try again.',
        malformedPayload => 'The settlement data was invalid and could not be processed.',
        emptySettlement => 'There is nothing to settle.',
        network => 'Could not reach the server. Check your connection and try again.',
        unknown => 'Something went wrong while settling. Please try again.',
      };
}

/// Typed settlement failure surfaced by the repository/controller.
class SettlementException implements Exception {
  final SettlementErrorKind kind;
  final String? detail;
  const SettlementException(this.kind, [this.detail]);

  String get message => detail ?? kind.message;

  @override
  String toString() => 'SettlementException(${kind.name}${detail == null ? '' : ': $detail'})';
}

/// SettlementRepository — port for redeeming received tokens at the backend
/// (FR-SET-01..05). Domain defines the interface; the data layer implements it
/// against POST /v1/settlement.
abstract interface class SettlementRepository {
  /// Settle [tokens] for [merchantId]. Throws [SettlementException] on a
  /// request-level failure (unknown merchant, malformed/empty payload, or a
  /// network error). Per-token outcomes are carried in the returned result.
  Future<SettlementResult> settle(String merchantId, List<Token> tokens);
}
