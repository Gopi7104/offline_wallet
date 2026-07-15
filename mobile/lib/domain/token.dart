import 'package:offline_wallet/core/money.dart';
import 'package:offline_wallet/core/result.dart';

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

  /// Wire form for BLE token transfer (Task 8). Compact keys; amounts in paise;
  /// timestamps epoch seconds; status by enum name; `sig` is the placeholder
  /// bank signature (Task 9 replaces it with a real Ed25519 issuer signature).
  Map<String, dynamic> toJson() => {
    'id': id,
    'denom': denomination.paise,
    'owner': ownerId,
    'iat': issuedAt.millisecondsSinceEpoch ~/ 1000,
    'exp': expiry.millisecondsSinceEpoch ~/ 1000,
    'status': status.name,
    'sig': bankSignature,
  };

  static Token fromJson(Map<String, dynamic> json) {
    final denom = switch (Money.fromPaise(json['denom'] as int)) {
      Ok(:final value) => value,
      Err() => Money.zero(),
    };
    return Token(
      id: json['id'] as String,
      denomination: denom,
      ownerId: json['owner'] as String,
      issuedAt: DateTime.fromMillisecondsSinceEpoch((json['iat'] as int) * 1000),
      expiry: DateTime.fromMillisecondsSinceEpoch((json['exp'] as int) * 1000),
      status: TokenStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => TokenStatus.inWallet,
      ),
      bankSignature: json['sig'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Token && id == other.id && ownerId == other.ownerId;

  @override
  int get hashCode => Object.hash(id, ownerId);
}

enum TokenStatus { minted, inWallet, inTransit, redeemed, expired, voided }
