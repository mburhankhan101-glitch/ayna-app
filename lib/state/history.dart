import 'package:flutter/foundation.dart';

import '../models/scan.dart';
import '../services/api_client.dart';

/// Past scans and the trend built from them.
///
/// Separate from [Session] rather than folded into it, because the two answer
/// different questions and fail differently. Session answers "who is this and
/// what screen do they belong on" — if it fails the app cannot proceed. This
/// answers "what have they done before", and if it fails the app is still
/// perfectly usable minus a list. Merging them would let a flaky history
/// request bounce someone to the sign-in screen.
class History extends ChangeNotifier {
  History(this._api);

  final ApiClient _api;

  List<ScanSummary> scans = const [];
  Trend? trend;
  bool loading = false;

  /// Set when the last load failed. Not surfaced as a blocking error: the
  /// screens fall back to their empty states, which are honest and useful on
  /// their own.
  ApiException? error;

  ScanSummary? get latest => scans.isEmpty ? null : scans.first;

  /// The most recent scan that actually produced a report.
  ///
  /// Not simply [latest]: a rejected photo is the newest scan but has nothing
  /// to show, and home leading with "your last result" over a rejection would
  /// be pointing at an empty room.
  ScanSummary? get latestWithResult {
    for (final s in scans) {
      if (s.hasResult) return s;
    }
    return null;
  }

  bool get hasAnyScan => scans.isNotEmpty;

  Future<void> load() async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();

    try {
      // Both together. They are read on the same screens at the same moment,
      // and two sequential round trips on a slow connection is two chances to
      // show a half-populated screen.
      final results = await Future.wait([_api.listScans(), _api.trend()]);

      scans = ((results[0]['scans'] as List?) ?? [])
          .map((e) => ScanSummary.fromJson(e as Map<String, dynamic>))
          .toList();
      trend = Trend.fromJson(results[1]);
    } on ApiException catch (e) {
      error = e;
    } catch (e) {
      error = ApiException(
        status: 0,
        title: 'Could not load your scans',
        detail: '$e',
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
