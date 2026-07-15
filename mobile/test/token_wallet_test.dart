import 'package:flutter_test/flutter_test.dart';
import 'package:offline_wallet/core/secure_storage.dart';
import 'package:offline_wallet/data/token_store.dart';
import 'package:offline_wallet/features/wallet/wallet_provider.dart';

/// In-memory SecureStore standing in for the Keystore/Keychain-backed store,
/// so persistence can be tested without a platform channel.
class InMemoryStore implements SecureStore {
  final Map<String, String> _data = {};
  @override
  Future<String?> read(String key) async => _data[key];
  @override
  Future<void> write(String key, String value) async => _data[key] = value;
  @override
  Future<void> delete(String key) async => _data.remove(key);
}

Future<void> _tick() => Future<void>.delayed(Duration.zero);

void main() {
  test('minted offline cash persists and is restored by a fresh wallet (app restart)',
      () async {
    final store = InMemoryStore();

    // First "app run": load ₹250.
    final first = TokenWalletNotifier(TokenMinter(), store);
    await _tick(); // let _restore() (empty) settle
    first.mint(25000);
    expect(first.balance.paise, 25000);
    await _tick(); // let _persist() write

    // Simulate an app restart: a brand-new notifier reads the same store.
    final restored = TokenWalletNotifier(TokenMinter(), store);
    await _tick(); // let _restore() load
    expect(restored.balance.paise, 25000);
    expect(restored.state.length, 2); // ₹200 + ₹50
  });

  test('spending persists — the reduced balance survives a restart', () async {
    final store = InMemoryStore();
    final wallet = TokenWalletNotifier(TokenMinter(), store);
    await _tick();
    wallet.mint(25000); // ₹200 + ₹50
    await _tick();

    // Spend the ₹200 token.
    final twoHundred = wallet.state.firstWhere((t) => t.denomination.paise == 20000);
    wallet.spend([twoHundred.id]);
    expect(wallet.balance.paise, 5000);
    await _tick();

    final restored = TokenWalletNotifier(TokenMinter(), store);
    await _tick();
    expect(restored.balance.paise, 5000); // NOT re-minted; the spend stuck
  });

  test('no store (unit/test mode) degrades to in-memory without throwing', () async {
    final wallet = TokenWalletNotifier(TokenMinter());
    await _tick();
    wallet.mint(10000);
    expect(wallet.balance.paise, 10000);
  });
}
