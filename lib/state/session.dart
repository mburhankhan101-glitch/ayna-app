import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

/// Where the user is in the journey into the app.
///
/// This is a single enum rather than a set of booleans on purpose: `signedIn &&
/// !hasProfile && !hasConsent` is three flags with eight combinations, most of
/// which are nonsense. One value has exactly the states that can actually
/// exist, and the router switches on it exhaustively.
enum SessionStage {
  /// Restoring a stored session. Distinct from signedOut so the sign-in button
  /// does not flash on screen for a returning user.
  starting,

  /// Never opened the app before. Onboarding has not been seen.
  onboarding,

  signedOut,

  /// Auth0 knows them; the backend has no profile. The age gate lives here.
  needsProfile,

  /// Profile exists, consent does not. No scan may be taken (FR-1).
  needsConsent,

  ready,
}

/// Holds auth and user state for the whole app.
///
/// A ChangeNotifier rather than a state-management package: the app has one
/// piece of shared state and a handful of screens reading it. A library would
/// be more machinery than the problem has.
class Session extends ChangeNotifier {
  Session({AuthService? auth, ApiClient? api}) : _auth = auth ?? AuthService() {
    _api = api ?? ApiClient(_auth);
  }

  final AuthService _auth;
  late final ApiClient _api;

  SessionStage _stage = SessionStage.starting;
  AynaUser? _user;
  String? _error;
  bool _onboardingSeen = false;

  /// A name the identity provider already knew, if any.
  ///
  /// Auth0's Google connection supplies one; its email connection does not.
  /// Kept so profile setup can skip asking someone who has already handed it
  /// over -- being asked twice for the same thing reads as an app that was not
  /// paying attention.
  String? _suggestedName;

  SessionStage get stage => _stage;
  AynaUser? get user => _user;
  String? get error => _error;

  ApiClient get api => _api;

  String? get suggestedName => _suggestedName;

  void _set(SessionStage stage, {AynaUser? user, String? error}) {
    _stage = stage;
    if (user != null) _user = user;
    _error = error;
    notifyListeners();
  }

  /// Called once at launch.
  Future<void> start() async {
    if (!await _auth.isSignedIn) {
      _set(_onboardingSeen ? SessionStage.signedOut : SessionStage.onboarding);
      return;
    }
    await refresh();
  }

  /// Marks onboarding complete for this launch.
  ///
  /// Not persisted yet — a reinstall or restart shows it again. Persisting it
  /// needs a preferences store, and adding one to satisfy a three-screen
  /// carousel is not worth the dependency today.
  void completeOnboarding() {
    _onboardingSeen = true;
    _set(SessionStage.signedOut);
  }

  Future<void> signIn() async {
    _set(SessionStage.starting);
    try {
      await _auth.signIn();
      await _readSuggestedName();
      await refresh();
    } on Object catch (e) {
      // Cancelling the browser is an ordinary thing to do, not an error worth
      // a red box. Anything else is worth showing.
      final cancelled =
          e.toString().contains('canceled') ||
          e.toString().contains('cancelled');
      _set(SessionStage.signedOut, error: cancelled ? null : e.toString());
    }
  }

  /// Reads whatever name the identity provider attached to the token.
  ///
  /// Best effort by design: a missing or unreadable profile means the name
  /// step asks, which is the correct fallback. Failing sign-in over a greeting
  /// would be absurd.
  Future<void> _readSuggestedName() async {
    try {
      final p = await _auth.userProfile();
      final n = (p?.givenName ?? p?.name ?? '').trim();
      if (n.isNotEmpty && !n.contains('@')) {
        // Auth0 falls back to the email address as `name` when it has nothing
        // better. Greeting someone as "Hello, sana.iqbal.com" is worse
        // than not greeting them at all.
        _suggestedName = n;
      }
    } catch (_) {
      // Nothing to do. The name step will ask.
    }
  }

  /// Re-reads the user from the server and recomputes the stage.
  ///
  /// The server decides, not the client: `hasConsent` is version-scoped, so a
  /// policy change can move a user backwards from ready to needsConsent, and
  /// only a fetch reveals that.
  Future<void> refresh() async {
    try {
      final json = await _api.getUserProfile();
      final user = AynaUser.fromJson(json);
      _set(
        user.hasConsent ? SessionStage.ready : SessionStage.needsConsent,
        user: user,
      );
    } on ApiException catch (e) {
      if (e.isProfileMissing) {
        _set(SessionStage.needsProfile);
      } else if (e.isUnauthenticated) {
        _set(SessionStage.signedOut);
      } else {
        _set(SessionStage.signedOut, error: '${e.title}. ${e.detail}');
      }
    }
  }

  /// Creates the backend profile after the age gate.
  ///
  /// Returns null on success, or a message to show. The 403 for being under
  /// age is deliberately NOT surfaced here — the caller routes to a dedicated
  /// screen for it, because a refusal that matters deserves more than a red
  /// line under a form.
  Future<String?> createProfile({
    required int birthYear,
    required String timezone,
    String? displayName,
  }) async {
    try {
      await _api.createUser(
        birthYear: birthYear,
        timezone: timezone,
        displayName: displayName,
      );
      await refresh();
      return null;
    } on ApiException catch (e) {
      if (e.isUnderMinimumAge) return _underAgeSentinel;
      return '${e.title}. ${e.detail}';
    }
  }

  /// Returned by [createProfile] when the server refused on age grounds.
  static const underAge = _underAgeSentinel;
  static const _underAgeSentinel = '__under_age__';

  Future<String?> grantConsent() async {
    try {
      await _api.setConsent(granted: true);
      await refresh();
      return null;
    } on ApiException catch (e) {
      return '${e.title}. ${e.detail}';
    }
  }

  Future<void> signOut() async {
    _set(SessionStage.starting);
    await _auth.signOut();
    _user = null;
    _set(SessionStage.signedOut);
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }
}
