import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_wallet/core/app_config.dart';
import 'package:offline_wallet/core/crypto/device_keypair_store.dart';
import 'package:offline_wallet/core/secure_storage.dart';
import 'package:offline_wallet/data/device_api_client.dart';
import 'package:offline_wallet/data/device_api_client_impl.dart';
import 'package:offline_wallet/features/auth/auth_provider.dart';

/// Device Registration wiring (production hardening §1, extended by Task 9 —
/// FR-PAY-04/FR-ID-02/03): after login, register this device (uploading its
/// Ed25519 public key) if it has never registered, otherwise just touch
/// last-seen. Reuses the existing device registration endpoints — no new
/// API surface.

const String _kDeviceIdKey = 'device_local_id_v1';
const String _kDeviceRegisteredKey = 'device_registered_v1';
const String _kAppVersion = '1.1.0'; // mirrors pubspec.yaml version

/// A stable per-install identifier, generated once and persisted. Not tied to
/// hardware serials (those need extra permissions and aren't stable across
/// factory reset) — a locally-generated id the app itself controls is the
/// standard, privacy-respecting choice, and it's what the device key is bound
/// to anyway.
Future<String> _getOrCreateDeviceId(SecureStore store) async {
  final existing = await store.read(_kDeviceIdKey);
  if (existing != null && existing.isNotEmpty) return existing;
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  final id = 'dev-${bytesToHex(bytes)}';
  await store.write(_kDeviceIdKey, id);
  return id;
}

String _platformName() => switch (defaultTargetPlatform) {
  TargetPlatform.android => 'android',
  TargetPlatform.iOS => 'ios',
  _ => 'web',
};

final deviceApiClientProvider = Provider<DeviceApiClient>((ref) {
  return DeviceApiClientImpl(
    baseUrl: AppConfig.apiBaseUrl,
    identity: ref.read(identityHeadersProvider),
  );
});

/// Fire-and-forget-ish: register (or touch last-seen) once per app session.
/// Best-effort like the wallet/merchant/settlement clients — an unreachable
/// backend must never block the offline-first app; this simply gets retried
/// next time the provider is (re)created.
final deviceRegistrationProvider = FutureProvider<void>((ref) async {
  final store = ref.watch(appSecureStorageProvider);
  final keys = ref.watch(deviceKeyPairStoreProvider);
  final api = ref.watch(deviceApiClientProvider);

  try {
    final deviceId = await _getOrCreateDeviceId(store);
    final alreadyRegistered = await store.read(_kDeviceRegisteredKey) == deviceId;

    if (!alreadyRegistered) {
      final publicKeyHex = await keys.publicKeyHex();
      await api.register(
        deviceId: deviceId,
        platform: _platformName(),
        deviceModel: '${_platformName()} device',
        appVersion: _kAppVersion,
        publicKeyHex: publicKeyHex,
      );
      await store.write(_kDeviceRegisteredKey, deviceId);
    } else {
      await api.touchLastSeen(deviceId);
    }
  } catch (_) {
    // Backend unreachable or a transient failure — proceed offline; this is
    // retried the next time the app builds this provider (e.g. next launch).
  }
});
