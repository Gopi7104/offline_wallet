/// App-wide runtime configuration (ARCHITECTURE.md §6.1 `core/ … config`).
///
/// The backend API base URL is resolved from a compile-time environment value
/// so it can be switched per target WITHOUT editing code:
///
///   flutter run  --dart-define=API_BASE_URL=http://10.0.2.2:3000
///   flutter build apk --dart-define=API_BASE_URL=https://api.example.com
///
/// Default target: **USB loopback via `adb reverse`**, not a LAN IP. Two
/// reasons this default keeps breaking otherwise (FR-ID-04 two-device
/// testing is a core scenario for this project):
///   1. A LAN IP is the dev Mac's address on ONE Wi-Fi network — it goes
///      stale the moment the Mac joins a different network.
///   2. It only ever reaches devices on the SAME Wi-Fi. A phone tethered on
///      cellular data (no Wi-Fi at all) can never route to a private LAN IP
///      behind NAT, no matter how fresh that IP is.
/// USB + `adb reverse` sidesteps both: it works over the cable regardless of
/// whichever network (or none) the phone's radio is on. Before running:
///   adb reverse tcp:3000 tcp:3000        # once per connected device
///   flutter run                          # or: flutter build apk
/// (Use 127.0.0.1, NOT `localhost`: strict Private DNS cannot resolve the name.)
///
/// Other targets:
///   • Android emulator: http://10.0.2.2:3000       (host-loopback alias)
///   • iOS simulator   : http://localhost:3000
///   • LAN IP fallback : http://<dev-mac-lan-ip>:3000 — only if the device
///     is on the same Wi-Fi and USB debugging isn't available.
///   • Production      : https://api.<your-domain>  (HTTPS)
///
/// Note: cleartext HTTP to 127.0.0.1/10.0.2.2/localhost is whitelisted in
/// android/app/src/main/res/xml/network_security_config.xml; production HTTPS
/// stays secure-by-default.
class AppConfig {
  AppConfig._();

  /// Backend API base URL (no trailing slash). Override with
  /// `--dart-define=API_BASE_URL=…`; defaults to the USB/adb-reverse loopback.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:3000',
  );
}
