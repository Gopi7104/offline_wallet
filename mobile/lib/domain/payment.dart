import 'package:offline_wallet/core/money.dart';

/// PaymentRequest — the customer's intent to pay a merchant (Task 5 placeholder).
/// Mirrors the backend Payment context. No coins move here; the real pay path is
/// offline (BLE) and lands in a later task.
class PaymentRequest {
  final String paymentRequestId;
  final String payerAccountId;
  final String merchantId;
  final String merchantName;
  final Money amount;
  final String status;

  const PaymentRequest({
    required this.paymentRequestId,
    required this.payerAccountId,
    required this.merchantId,
    required this.merchantName,
    required this.amount,
    required this.status,
  });
}
