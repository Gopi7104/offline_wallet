import 'payment.dart';

/// PaymentRepository — port for the Customer Pay flow (Task 5). Domain defines
/// the interface; the data layer implements it against the backend API.
abstract interface class PaymentRepository {
  /// Create a placeholder payment request. The backend validates that the
  /// merchant exists and the amount is a positive integer (paise). Throws on a
  /// validation/lookup failure so the UI can surface a message.
  Future<PaymentRequest> createPaymentRequest({
    required String merchantId,
    required int amountPaise,
  });
}
