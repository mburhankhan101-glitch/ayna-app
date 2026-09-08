import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'auth_service.dart';

/// A failure the UI can act on.
///
/// Modelled on the backend's RFC 9457 problem bodies, because the API returns
/// exactly one error shape and the client should not invent a second one.
class ApiException implements Exception {
  ApiException({
    required this.status,
    required this.title,
    required this.detail,
    this.type = '',
    this.correlationId = '',
    this.resetsAt,
  });

  final int status;
  final String title;
  final String detail;
  final String type;

  /// Ties this failure to a specific server log line (NFR-9). Worth surfacing
  /// somewhere copyable when things go wrong — it turns "it didn't work" into
  /// a single grep.
  final String correlationId;

  /// When a rate-limited action becomes available again.
  ///
  /// Sent by the server on a 429 because only the server knows the rolling
  /// window. The client must never compute this itself -- an app that guesses
  /// "a week from now" tells a user to come back on the wrong day.
  final DateTime? resetsAt;

  /// True when the caller should route to sign-in rather than show an error.
  bool get isUnauthenticated => status == 401;

  /// True when the account has not been set up yet — expected immediately
  /// after a first login, not a failure.
  bool get isProfileMissing => status == 404 && type.endsWith('/no-profile');

  bool get isUnderMinimumAge => type.endsWith('/under-minimum-age');

  /// True when the weekly scan allowance is used up. Not a failure: the user
  /// did nothing wrong and the answer is a date, not an apology.
  bool get isAllowanceExhausted => status == 429;

  @override
  String toString() => '$status $title: $detail';
}

/// Talks to the Ayna backend.
///
/// Every request carries the Auth0 access token. There is no unauthenticated
/// path here on purpose — the health probes are for Cloud Run, not for the app.
class ApiClient {
  ApiClient(this._auth, {http.Client? client})
    : _client = client ?? http.Client();

  final AuthService _auth;
  final http.Client _client;

  static const _timeout = Duration(seconds: 20);

  Future<Map<String, dynamic>> getUserProfile() async =>
      _send('GET', '/v1/users/me');

  Future<Map<String, dynamic>> createUser({
    required int birthYear,
    required String timezone,
    String? displayName,
  }) => _send(
    'POST',
    '/v1/users',
    body: {
      'birthYear': birthYear,
      'timezone': timezone,
      if (displayName != null && displayName.isNotEmpty)
        'displayName': displayName,
    },
  );

  /// FR-11. Returns 202 with the purge SLA; the row is not gone yet when this
  /// resolves, which is why the caller signs out rather than continuing.
  Future<Map<String, dynamic>> deleteAccount() =>
      _send('DELETE', '/v1/users/me');

  /// Sets how long photos are kept, in days (NFR-4). Null means keep them.
  ///
  /// Returns the updated profile, so the caller refreshes from the server's
  /// answer rather than assuming its own request succeeded exactly as sent.
  ///
  /// The key is always present in the body, with an explicit null for "keep
  /// indefinitely". Omitting it would be indistinguishable from "don't change
  /// this", and the server would have no way to tell the two apart.
  Future<Map<String, dynamic>> setPhotoRetention(int? days) =>
      _send('PATCH', '/v1/users/me', body: {'photoRetentionDays': days});

  Future<Map<String, dynamic>> setConsent({required bool granted}) => _send(
    'POST',
    '/v1/consent',
    body: {'policyVersion': AppConfig.consentPolicyVersion, 'granted': granted},
  );

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = await _auth.accessToken();
    if (token == null) {
      // Fail before the round trip. The server would return 401 anyway, but a
      // request we already know is unauthenticated is a wasted second on a
      // slow connection and a confusing log line on the server.
      throw ApiException(
        status: 401,
        title: 'Sign in to continue',
        detail: 'Your session has ended.',
        type: 'local/not-authenticated',
      );
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final request = http.Request(method, uri)
      ..headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json',
      });
    if (body != null) request.body = jsonEncode(body);

    late http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(_timeout),
      );
    } on SocketException {
      // Distinguished from a server error because the fix is different and the
      // user can act on it: turn the connection on, or the dev machine's
      // `adb reverse` is not running.
      throw ApiException(
        status: 0,
        title: 'No connection',
        detail: 'Check your internet connection and try again.',
        type: 'local/offline',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return const {};
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw _problemFrom(response);
  }

  /// Turns a problem+json body into an ApiException, falling back sensibly
  /// when the body is not what we expect — a proxy or load balancer can return
  /// HTML for a 502, and parsing that as JSON would replace a useful status
  /// code with a FormatException.
  ApiException _problemFrom(http.Response response) {
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return ApiException(
        status: response.statusCode,
        title: (decoded['title'] as String?) ?? 'Something went wrong',
        detail: (decoded['detail'] as String?) ?? '',
        type: (decoded['type'] as String?) ?? '',
        correlationId: (decoded['correlationId'] as String?) ?? '',
        // Only the server knows the rolling window. A client that computed
        // "a week from now" itself would send the user back on the wrong day.
        resetsAt: DateTime.tryParse(
          (decoded['resetsAt'] as String?) ?? '',
        )?.toLocal(),
      );
    } catch (_) {
      return ApiException(
        status: response.statusCode,
        title: 'Something went wrong',
        detail: 'The server returned an unexpected response.',
      );
    }
  }

  // -------------------------------------------------------------------------
  // Scans
  // -------------------------------------------------------------------------

  /// Submits a photo for analysis. Returns the scan's initial status.
  ///
  /// [idempotencyKey] must be **generated once per user intent, not per
  /// attempt**. That distinction is the whole feature: a retry after a dropped
  /// connection reuses the key and returns the original scan, while a genuinely
  /// new scan gets a new key. Regenerating it on retry would buy a second paid
  /// vendor call and burn a second scan from the user's week.
  Future<Map<String, dynamic>> submitScan({
    required File photo,
    required String idempotencyKey,
  }) async {
    final token = await _auth.accessToken();
    if (token == null) {
      throw ApiException(
        status: 401,
        title: 'Sign in to continue',
        detail: 'Your session has ended.',
        type: 'local/not-authenticated',
      );
    }

    // multipart, matching the server. Base64 in JSON would inflate a 1MB photo
    // by a third on a connection this product cannot assume is good.
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('${AppConfig.apiBaseUrl}/v1/scans'),
          )
          ..headers.addAll({
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Idempotency-Key': idempotencyKey,
          })
          ..files.add(await http.MultipartFile.fromPath('photo', photo.path));

    late http.Response response;
    try {
      response = await http.Response.fromStream(
        // A longer timeout than the rest of the API: this request carries an
        // upload AND waits on the vendor. 20s would abandon a scan that was
        // about to succeed on a slow connection, and the user would be charged
        // for it server-side while seeing a failure.
        await _client.send(request).timeout(const Duration(seconds: 45)),
      );
    } on SocketException {
      throw ApiException(
        status: 0,
        title: 'No connection',
        detail: 'Check your internet connection and try again.',
        type: 'local/offline',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw _problemFrom(response);
  }

  Future<Map<String, dynamic>> listScans({int limit = 20}) =>
      _send('GET', '/v1/scans?limit=$limit');

  Future<Map<String, dynamic>> trend() => _send('GET', '/v1/profile/me/trend');

  Future<Map<String, dynamic>> scanStatus(String scanId) =>
      _send('GET', '/v1/scans/$scanId');

  /// The redness overlay, as JPEG bytes.
  ///
  /// Returns null when there is no overlay — a free-tier scan, or one where the
  /// vendor map could not be trusted. That is a tier difference rather than a
  /// failure, and the report reads perfectly well without it.
  ///
  /// Never throws, deliberately. A missing decoration must not be able to break
  /// the report it decorates.
  Future<Uint8List?> scanHeatmap(String scanId) async {
    try {
      final token = await _auth.accessToken();
      if (token == null) return null;

      final res = await _client
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/v1/scans/$scanId/heatmap'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);

      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
      return res.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> scanReport(String scanId) =>
      _send('GET', '/v1/scans/$scanId/report');

  void close() => _client.close();
}
