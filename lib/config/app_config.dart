/// Build-time configuration.
///
/// Supplied with `--dart-define` rather than hardcoded, so the same source
/// builds against a local backend, staging, or production without edits.
///
/// None of these are secrets. A mobile app is a file anyone can unzip, so
/// nothing shipped in it is private — the Auth0 client id is *designed* to be
/// public, which is exactly why native apps use PKCE and no client secret. If
/// you ever find yourself wanting to put a secret here, the answer is that the
/// operation belongs on the backend instead.
abstract final class AppConfig {
  static const auth0Domain = String.fromEnvironment(
    'AUTH0_DOMAIN',
    defaultValue: 'dev-yqk2n1s3sblxcyyj.us.auth0.com',
  );

  /// The 'Ayna Mobile' native application.
  ///
  /// Replaced the original quickstart app, which could not be authorized for a
  /// custom API audience: /authorize succeeded without `audience` and failed
  /// with it, which isolates the fault to that application object rather than
  /// anything in this codebase. A freshly created Native app is first-party
  /// with the right grant types by default.
  static const auth0ClientId = String.fromEnvironment(
    'AUTH0_CLIENT_ID',
    defaultValue: 'lbf16iIMYUXLfCy6Vb0psIGTrN7YtjLr',
  );

  /// The API identifier from Auth0.
  ///
  /// This is the single most consequential line in the file. **Omit the
  /// audience on a login call and Auth0 returns an opaque access token** — a
  /// random string with no claims and nothing to verify — and the backend
  /// rejects every request with a 401 that says nothing about why. Passing it
  /// is what makes Auth0 issue a JWT for this specific API.
  static const auth0Audience = String.fromEnvironment(
    'AUTH0_AUDIENCE',
    defaultValue: 'https://api.ayna.app',
  );

  /// Where the Go backend lives.
  ///
  /// The default assumes `adb reverse tcp:8080 tcp:8080`, which maps the
  /// phone's own localhost to the development machine's. That is far less
  /// brittle than hardcoding a LAN IP, which changes every time the laptop
  /// joins a different network.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// The consent wording currently in force. Must match the backend's
  /// `CurrentPolicyVersion` — consent is version-scoped, so a mismatch means
  /// the user consents to something the server never asks about and is
  /// prompted forever.
  static const consentPolicyVersion = '2026-08-01';

  /// Scopes requested at login. `offline_access` is what yields a refresh
  /// token; without it the user is signed out the moment the access token
  /// expires, which for Auth0 defaults to 24 hours.
  static const authScopes = {'openid', 'profile', 'email', 'offline_access'};
}
