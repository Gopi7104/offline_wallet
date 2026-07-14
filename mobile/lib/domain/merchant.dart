import 'package:offline_wallet/core/money.dart';

/// MerchantWallet — the two buckets a merchant cares about (FR-MER-02): funds
/// received but not yet settled, and funds already settled. Task 4: both start
/// at zero (settlement lands in a later task). Immutable.
class MerchantWallet {
  final Money pendingSettlement;
  final Money settled;

  const MerchantWallet({
    required this.pendingSettlement,
    required this.settled,
  });

  static MerchantWallet empty() =>
      MerchantWallet(pendingSettlement: Money.zero(), settled: Money.zero());

  Money get total => pendingSettlement.add(settled);

  @override
  bool operator ==(Object other) =>
      other is MerchantWallet &&
      other.pendingSettlement == pendingSettlement &&
      other.settled == settled;

  @override
  int get hashCode => Object.hash(pendingSettlement, settled);
}

/// Merchant — Merchant Mode entity (FR-MER-01). A role on an existing account:
/// minted with a Merchant ID and an empty wallet, no separate registration.
class Merchant {
  final String merchantId;
  final String accountId;
  final String displayName;
  final MerchantWallet wallet;

  const Merchant({
    required this.merchantId,
    required this.accountId,
    required this.displayName,
    required this.wallet,
  });

  @override
  bool operator ==(Object other) =>
      other is Merchant &&
      other.merchantId == merchantId &&
      other.accountId == accountId &&
      other.displayName == displayName &&
      other.wallet == wallet;

  @override
  int get hashCode => Object.hash(merchantId, accountId, displayName, wallet);
}

/// QrPayload — placeholder payment-QR contents (FR-PAY-01). Mirrors the backend
/// wire contract {v, merchant_id, nonce, ts, amount?} and carries no secrets.
/// Task 4 is a placeholder: no signing, no single-use nonce tracking yet.
class QrPayload {
  final int v;
  final String merchantId;
  final String nonce;
  final String ts;
  final int? amountPaise;

  const QrPayload({
    required this.v,
    required this.merchantId,
    required this.nonce,
    required this.ts,
    this.amountPaise,
  });
}
