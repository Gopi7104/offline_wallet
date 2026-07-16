import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/core/app_config.dart';
import 'package:offline_wallet/data/settlement_api_client_impl.dart';
import 'package:offline_wallet/data/settlement_repository_impl.dart';
import 'package:offline_wallet/domain/settlement.dart';
import 'package:offline_wallet/domain/token.dart';
import 'package:offline_wallet/features/auth/auth_provider.dart';

import 'pending_settlement_provider.dart';

/// Settlement screen phase (idle → processing → summary | error).
enum SettlementPhase { idle, processing, success, error }

/// UI state for the Settlement screen (Task 9).
class SettlementUiState {
  final SettlementPhase phase;
  final SettlementResult? result;
  final SettlementException? error;

  const SettlementUiState({
    this.phase = SettlementPhase.idle,
    this.result,
    this.error,
  });

  bool get isProcessing => phase == SettlementPhase.processing;
}

/// SettlementController — drives POST /v1/settlement from the merchant's
/// pending tokens, then hands the result to the pending-settlement store so
/// Pending becomes Settled. Rejections (unknown merchant, malformed/empty,
/// network) surface as an error phase the screen renders as a Material dialog.
class SettlementController extends StateNotifier<SettlementUiState> {
  final SettlementRepository _repository;
  final void Function(SettlementResult) _onSettled;

  SettlementController({
    required SettlementRepository repository,
    required void Function(SettlementResult) onSettled,
  })  : _repository = repository,
        _onSettled = onSettled,
        super(const SettlementUiState());

  Future<void> settle(String merchantId, List<Token> tokens) async {
    if (state.isProcessing) return;
    if (tokens.isEmpty) {
      state = const SettlementUiState(
        phase: SettlementPhase.error,
        error: SettlementException(SettlementErrorKind.emptySettlement),
      );
      return;
    }
    state = const SettlementUiState(phase: SettlementPhase.processing);
    try {
      final result = await _repository.settle(merchantId, tokens);
      _onSettled(result);
      state = SettlementUiState(phase: SettlementPhase.success, result: result);
    } on SettlementException catch (e) {
      state = SettlementUiState(phase: SettlementPhase.error, error: e);
    } catch (e) {
      state = SettlementUiState(
        phase: SettlementPhase.error,
        error: SettlementException(SettlementErrorKind.unknown, '$e'),
      );
    }
  }
}

final settlementRepositoryProvider = Provider<SettlementRepository>((ref) {
  final apiClient = SettlementApiClientImpl(
    baseUrl: AppConfig.apiBaseUrl,
    identity: ref.read(identityHeadersProvider),
  );
  return SettlementRepositoryImpl(apiClient: apiClient);
});

final settlementControllerProvider = StateNotifierProvider.autoDispose<
    SettlementController, SettlementUiState>((ref) {
  return SettlementController(
    repository: ref.watch(settlementRepositoryProvider),
    onSettled: (result) =>
        ref.read(pendingSettlementProvider.notifier).markSettled(result),
  );
});
