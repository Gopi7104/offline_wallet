import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/core/app_config.dart';
import 'package:offline_wallet/data/payment_api_client_impl.dart';
import 'package:offline_wallet/data/payment_repository_impl.dart';
import 'package:offline_wallet/domain/payment_repository.dart';

/// Customer Pay state (ARCHITECTURE.md §6.1 `pay/` — payer role).
/// Task 5: scan (placeholder) → summary → amount → confirm → success.

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final apiClient = PaymentApiClientImpl(baseUrl: AppConfig.apiBaseUrl);
  return PaymentRepositoryImpl(apiClient: apiClient);
});
