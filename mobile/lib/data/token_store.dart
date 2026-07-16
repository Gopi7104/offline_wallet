import 'package:offline_wallet/core/money.dart';
import 'package:offline_wallet/core/result.dart';
import 'package:offline_wallet/domain/denominations.dart';
import 'package:offline_wallet/domain/token.dart';

/// Coin expiry window (PAYMENT_PROTOCOL.md §10): minted tokens are valid 90d.
const Duration kTokenValidity = Duration(days: 90);

/// Placeholder issuer signature. Task 9 replaces this with a real Ed25519
/// signature from the bank issuer key (this is a documented prototype limit).
const String kPlaceholderIssuerSig = 'issuer-sig-placeholder';

/// Mints local digital-cash [Token]s. In the prototype the "bank" mints
/// client-side when the wallet is loaded (approved Task-8 decision); Task 9
/// moves minting server-side with real signatures. Not a Riverpod type — the
/// stateful holder is `tokenWalletProvider` in `features/wallet/`.
class TokenMinter {
  int _counter = 0;

  /// Mint the exact denomination breakdown of [amountPaise] for [ownerId].
  /// Returns an empty list if the amount can't be represented in the canonical
  /// denominations (e.g. not a whole rupee).
  List<Token> mint(int amountPaise, {required String ownerId}) {
    final breakdown = mintBreakdown(amountPaise);
    if (breakdown == null) return const [];
    final now = DateTime.now();
    final expiry = now.add(kTokenValidity);
    return breakdown.map((denomPaise) {
      final denom = switch (Money.fromPaise(denomPaise)) {
        Ok(:final value) => value,
        Err() => Money.zero(),
      };
      return Token(
        id: 'tok-${now.microsecondsSinceEpoch}-${_counter++}',
        denomination: denom,
        ownerId: ownerId,
        issuedAt: now,
        expiry: expiry,
        status: TokenStatus.inWallet,
        bankSignature: kPlaceholderIssuerSig,
      );
    }).toList();
  }
}
