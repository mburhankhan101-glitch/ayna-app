import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

/// Wraps Auth0 login, logout and token access.
///
/// The rest of the app never touches `auth0_flutter` directly — it asks this
/// for a token and gets one, or doesn't. That keeps the identity provider
/// swappable and, more usefully day to day, keeps the "is the token still
/// valid?" logic in exactly one place instead of at every call site.
class AuthService {
  AuthService()
    : _auth0 = Auth0(AppConfig.auth0Domain, AppConfig.auth0ClientId);

  final Auth0 _auth0;

  /// The custom URI scheme the Auth0 browser redirect comes back on.
  ///
  /// NOT the applicationId, and it cannot be: URI schemes forbid underscores
  /// (RFC 3986) and the applicationId is com.ayna.ayna_app. Must match
  /// manifestPlaceholders["auth0Scheme"] in android/app/build.gradle.kts, and
  /// the callback URL registered in the Auth0 dashboard.
  ///
  /// Declared once here so the two login/logout call sites cannot drift.
  static const callbackScheme = 'com.ayna.aynaapp';

  /// Credentials are held by the platform SDK in the Android Keystore, not in
  /// SharedPreferences or anywhere this Dart code could leak them.
  CredentialsManager get _credentials => _auth0.credentialsManager;

  /// Whether a usable session exists.
  ///
  /// `hasValidCredentials` accounts for refresh: an expired access token with
  /// a live refresh token still counts, because the SDK will renew it
  /// transparently on the next `credentials()` call.
  Future<bool> get isSignedIn => _credentials.hasValidCredentials();

  /// Opens the hosted login page and stores the resulting credentials.
  ///
  /// `useHTTPS` is deliberately false: on Android that would require App Links
  /// with a verified domain, which needs a real domain serving an
  /// assetlinks.json. The custom scheme registered in build.gradle.kts is the
  /// right choice until there is one.
  Future<Credentials> signIn() async {
    final credentials = await _auth0
        .webAuthentication(scheme: callbackScheme)
        .login(
          // Without this the token comes back opaque and the backend rejects
          // it. See AppConfig.auth0Audience.
          audience: AppConfig.auth0Audience,
          scopes: AppConfig.authScopes,
        );

    await _credentials.storeCredentials(credentials);
    return credentials;
  }

  /// Clears the local session and the Auth0 browser session.
  ///
  /// Both, deliberately: clearing only the local one leaves the hosted login
  /// page still authenticated, so the next "sign in" silently returns the same
  /// user without asking — which looks broken to anyone trying to switch
  /// accounts.
  Future<void> signOut() async {
    try {
      await _auth0.webAuthentication(scheme: callbackScheme).logout();
    } on WebAuthenticationException catch (e) {
      // A cancelled logout must not leave the app in a half-signed-out state,
      // so the local clear below happens regardless.
      debugPrint('auth0 logout: $e');
    }
    await _credentials.clearCredentials();
  }

  /// A valid access token, refreshing it if needed.
  ///
  /// Returns null when there is no usable session, rather than throwing: an
  /// expired session is an ordinary event, not an exceptional one, and callers
  /// should route to sign-in rather than catch an exception.
  Future<String?> accessToken() async {
    try {
      if (!await _credentials.hasValidCredentials()) return null;
      final credentials = await _credentials.credentials();
      return credentials.accessToken;
    } on CredentialsManagerException catch (e) {
      debugPrint('auth0 credentials: $e');
      return null;
    }
  }

  /// The signed-in user's profile claims, or null.
  Future<UserProfile?> userProfile() async {
    try {
      if (!await _credentials.hasValidCredentials()) return null;
      return (await _credentials.credentials()).user;
    } on CredentialsManagerException {
      return null;
    }
  }
}
