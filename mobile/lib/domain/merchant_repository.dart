import 'merchant.dart';

/// MerchantRepository — port for Merchant Mode (FR-MER-01/02). Domain defines
/// the interface; the data layer implements it against the backend API.
abstract interface class MerchantRepository {
  /// Enable Merchant Mode for the account (idempotent). Returns the merchant.
  Future<Merchant> enableMerchantMode(String accountId, {String? displayName});

  /// Fetch the merchant dashboard state, or null if Merchant Mode is off.
  Future<Merchant?> getMerchant(String accountId);

  /// Generate a placeholder payment-QR payload (FR-PAY-01).
  Future<QrPayload> generateQrPayload(String accountId, {int? amountPaise});
}
