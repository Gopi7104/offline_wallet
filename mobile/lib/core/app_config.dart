/// App-wide runtime configuration (ARCHITECTURE.md §6.1 `core/ … config`).
///
/// The backend API base URL is resolved from a compile-time environment value
/// so it can be switched per target WITHOUT editing code:
///
///   flutter run  --dart-define=API_BASE_URL=http://10.0.2.2:3000
///   flutter build apk --dart-define=API_BASE_URL=https://api.example.com
///
/// Common targets:
///   • Physical device : http://10.205.185.61:3000  (this dev Mac's LAN IP — the
///                       default, so `flutter run` works on the phone out of the
///                       box; the phone cannot reach the Mac via `localhost`).
///   • Android emulator: http://10.0.2.2:3000       (host-loopback alias)
///   • iOS simulator   : http://localhost:3000
///   • Production      : https://api.<your-domain>  (HTTPS)
///
/// USB fallback (works even when the Wi-Fi blocks device→Mac LAN traffic, e.g.
/// a guest network or strict Private DNS): tunnel over the cable, then use the
/// loopback literal —
///   adb reverse tcp:3000 tcp:3000
///   flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3000
/// (Use 127.0.0.1, NOT `localhost`: strict Private DNS cannot resolve the name.)
///
/// Note: cleartext HTTP to the dev IPs is whitelisted in
/// android/app/src/main/res/xml/network_security_config.xml; production HTTPS
/// stays secure-by-default.
class AppConfig {
  AppConfig._();

  /// Backend API base URL (no trailing slash). Override with
  /// `--dart-define=API_BASE_URL=…`; defaults to the dev Mac's LAN IP.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.205.185.61:3000',
  );
}
