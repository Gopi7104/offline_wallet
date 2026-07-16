import 'dart:io';

import 'package:offline_wallet/core/money.dart';
import 'package:offline_wallet/core/result.dart';
import 'package:offline_wallet/domain/settlement.dart';
import 'package:offline_wallet/domain/token.dart';
import 'settlement_api_client.dart';

/// Concrete settlement repository (data layer). Serializes tokens to the wire
/// shape, calls POST /v1/settlement, and maps the response / error codes to
/// domain types. Network and server errors become [SettlementException]s so
/// the UI can show the right Material dialog.
class SettlementRepositoryImpl implements SettlementRepository {
  final SettlementApiClient apiClient;

  SettlementRepositoryImpl({required this.apiClient});

  @override
  Future<SettlementResult> settle(String merchantId, List<Token> tokens) async {
    try {
      final response = await apiClient.settle(
        merchantId: merchantId,
        tokensJson: tokens.map((t) => t.toJson()).toList(),
      );
      return _toDomain(response);
    } on SettlementApiException catch (e) {
      throw SettlementException(SettlementErrorKind.fromCode(e.code), e.message);
    } on SocketException {
      throw const SettlementException(SettlementErrorKind.network);
    } on HttpException {
      throw const SettlementException(SettlementErrorKind.network);
    }
  }

  SettlementResult _toDomain(SettlementResponse r) {
    return SettlementResult(
      settlementId: r.settlementId,
      accepted: r.accepted,
      rejected: r.rejected,
      duplicates: r.duplicates,
      creditedAmount: _money(r.creditedPaise),
      ledgerId: r.ledgerId,
      status: SettlementStatus.fromWire(r.status),
    );
  }

  Money _money(int paise) => switch (Money.fromPaise(paise)) {
        Ok(:final value) => value,
        Err() => Money.zero(),
      };
}
