/// Backend identity headers for the current session (FR-ID-01). A signed-in
/// Firebase user resolves to `Authorization: Bearer <idToken>`; Guest Mode
/// (no Firebase session) falls back to the legacy `x-account-id` header
/// keyed by the guest's local id. Implemented by
/// `features/auth/auth_provider.dart` (`identityHeadersProvider`) — the
/// typedef lives in `core/` so `data/` API clients don't depend on
/// `features/auth`.
typedef IdentityHeaders = Future<Map<String, String>> Function();
