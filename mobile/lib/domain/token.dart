import 'package:offline_wallet/core/money.dart';

/// Token — digital cash entity (mirrors backend ARCHITECTURE.md §4.2, §4.3).
/// Immutable. Fields: id, denomination, ownerId, issuedAt, expiry, status, signature.
/// Task 3: placeholder signature; Task 4 adds Ed25519.
class Token {
  final String id;
  final Money denomination;
  final String ownerId;
  final DateTime issuedAt;
  final DateTime expiry;
  final TokenStatus status;
  final String bankSignature; // Placeholder

  const Token({
    required this.id,
    required this.denomination,
    required this.ownerId,
    required this.issuedAt,
    required this.expiry,
    required this.status,
    required this.bankSignature,
  });

  bool isExpired(DateTime now) => now.isAfter(expiry);

  /// Immutable: return a new Token with updated status.
  Token copyWithStatus(TokenStatus newStatus) => Token(
    id: id,
    denomination: denomination,
    ownerId: ownerId,
    issuedAt: issuedAt,
    expiry: expiry,
    status: newStatus,
    bankSignature: bankSignature,
  );

  @override
  bool operator ==(Object other) =>
      other is Token && id == other.id && ownerId == other.ownerId;

  @override
  int get hashCode => Object.hash(id, ownerId);
}

enum TokenStatus { minted, inWallet, inTransit, redeemed, expired, voided }
