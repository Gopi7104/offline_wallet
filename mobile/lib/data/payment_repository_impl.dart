import 'package:offline_wallet/core/money.dart';
import 'package:offline_wallet/core/result.dart';
import 'package:offline_wallet/domain/payment.dart';
import 'package:offline_wallet/domain/payment_repository.dart';
import 'payment_api_client.dart';

/// Concrete payment repository (data layer). Maps the wire DTO → domain entity.
/// Task 5: stateless placeholder (no local persistence).
class PaymentRepositoryImpl implements PaymentRepository {
  final PaymentApiClient apiClient;

  PaymentRepositoryImpl({required this.apiClient});

  @override
  Future<PaymentRequest> createPaymentRequest({
    required String merchantId,
    required int amountPaise,
  }) async {
    final r = await apiClient.createPaymentRequest(
      merchantId: merchantId,
      amountPaise: amountPaise,
    );
    return PaymentRequest(
      paymentRequestId: r.paymentRequestId,
      payerAccountId: r.payerAccountId,
      merchantId: r.merchantId,
      merchantName: r.merchantName,
      amount: _money(r.amountPaise),
      status: r.status,
    );
  }

  Money _money(int paise) => switch (Money.fromPaise(paise)) {
        Ok(:final value) => value,
        Err() => Money.zero(),
      };
}
