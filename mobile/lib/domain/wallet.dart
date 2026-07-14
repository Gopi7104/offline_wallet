import 'package:offline_wallet/core/money.dart';

/// Wallet entity (Task 3: balance only, tokens internal to backend).
/// Task 8: will add local token storage when we implement offline payment.
/// For now, just tracks the total balance cached from the API.
class Wallet {
  final String accountId;
  final Money balance;

  const Wallet({
    required this.accountId,
    required this.balance,
  });

  static Wallet empty(String accountId) =>
      Wallet(accountId: accountId, balance: Money.zero());

  Wallet copyWithBalance(Money newBalance) =>
      Wallet(accountId: accountId, balance: newBalance);

  @override
  bool operator ==(Object other) =>
      other is Wallet && accountId == other.accountId && balance == other.balance;

  @override
  int get hashCode => Object.hash(accountId, balance);
}
