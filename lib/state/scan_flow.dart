import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/scan.dart';
import '../services/api_client.dart';

enum ScanFlowState { idle, working, done, rejected, failed, error }

/// Drives one scan from photo to report.
///
/// Owns the two things the screens must not: the idempotency key, and the
/// pacing of the progress display.
class ScanFlow extends ChangeNotifier {
  ScanFlow(this._api);

  final ApiClient _api;

  ScanFlowState state = ScanFlowState.idle;
  ScanProgress? progress;
  SkinReport? report;

  /// The redness overlay for the finished scan, or null.
  ///
  /// Fetched after the report and never awaited as a precondition: a slow or
  /// missing overlay must not delay the result the user waited for.
  Uint8List? heatmap;
  ApiException? error;

  Timer? _pacer;
  String? _key;

  /// The step the UI shows.
  ///
  /// Server-reported when the server has said anything; **client-paced
  /// otherwise**, and that fallback is a deliberate, temporary fiction worth
  /// naming.
  ///
  /// The analysis currently runs inside POST /v1/scans, so the client has no
  /// scan id to poll until the work is already finished — there is nothing to
  /// report progress *from*. The stages are therefore walked locally against
  /// the server's own `estimatedSeconds`, which is a measured figure (p95 2.9s)
  /// rather than an invention.
  ///
  /// The moment the analysis moves to the worker, [progress] starts carrying a
  /// real stage and this fallback stops being used. No screen changes.
  ScanStage stage = ScanStage.received;

  bool get isBusy => state == ScanFlowState.working;

  /// A key per user intent, generated once here.
  ///
  /// Deliberately NOT regenerated on retry: reusing it is what makes a second
  /// attempt free instead of a second paid vendor call and a second scan off
  /// the user's week. A new key is minted only by [reset], which is a new
  /// intent.
  String get _idempotencyKey => _key ??= _mintKey();

  Future<void> start(File photo) async {
    if (state == ScanFlowState.working) return;

    state = ScanFlowState.working;
    stage = ScanStage.received;
    report = null;
    error = null;
    notifyListeners();

    _startPacing();

    try {
      final submitted = ScanProgress.fromJson(
        await _api.submitScan(photo: photo, idempotencyKey: _idempotencyKey),
      );
      progress = submitted;

      // Poll only if the server is genuinely still working. Today it never is
      // — the analysis finished inside the POST — but the loop exists so the
      // client needs no change when the worker lands.
      var current = submitted;
      var attempts = 0;
      while (!current.isDone && attempts < 40) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        current = ScanProgress.fromJson(await _api.scanStatus(current.scanId));
        progress = current;
        if (current.stage != null) stage = current.stage!;
        notifyListeners();
        attempts++;
      }

      switch (current.state) {
        case ScanState.completed:
          report = SkinReport.fromJson(await _api.scanReport(current.scanId));
          _finish(ScanFlowState.done);
          // After finishing, deliberately. The report is what the user waited
          // for; the overlay arrives into an already-visible screen.
          heatmap = await _api.scanHeatmap(current.scanId);
          notifyListeners();
        case ScanState.rejected:
          // A rejection is not an error and cost the user nothing. It gets its
          // own state so the UI can offer a retake rather than an apology.
          _finish(ScanFlowState.rejected);
        case ScanState.failed:
          _finish(ScanFlowState.failed);
        case ScanState.processing:
          // Ran out of attempts. The scan may still complete server-side, so
          // this is not a failure of the scan — only of this wait.
          _finish(ScanFlowState.failed);
      }
    } on ApiException catch (e) {
      error = e;
      _finish(ScanFlowState.error);
    } catch (e) {
      error = ApiException(
        status: 0,
        title: 'Something went wrong',
        detail: '$e',
      );
      _finish(ScanFlowState.error);
    }
  }

  /// Walks the named steps locally while the request is in flight.
  ///
  /// Paced so the last step is reached slightly *after* the typical response,
  /// never before: a screen that says "just finishing up" and then keeps
  /// waiting is the exact thing that makes progress indicators untrustworthy.
  void _startPacing() {
    _pacer?.cancel();
    const order = [
      ScanStage.received,
      ScanStage.qualityChecked,
      ScanStage.scoring,
      ScanStage.writingReport,
    ];
    var i = 0;

    _pacer = Timer.periodic(const Duration(milliseconds: 950), (t) {
      // A real stage from the server always wins. Once polling reports
      // anything, the local walk stops guessing.
      if (progress?.stage != null) {
        t.cancel();
        return;
      }
      if (i >= order.length - 1) {
        t.cancel();
        return;
      }
      i++;
      stage = order[i];
      notifyListeners();
    });
  }

  void _finish(ScanFlowState s) {
    _pacer?.cancel();
    _pacer = null;
    state = s;
    notifyListeners();
  }

  /// Clears everything for a genuinely new scan, including the key.
  void reset() {
    _pacer?.cancel();
    _pacer = null;
    _key = null;
    state = ScanFlowState.idle;
    stage = ScanStage.received;
    progress = null;
    report = null;
    error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pacer?.cancel();
    super.dispose();
  }

  static String _mintKey() {
    // Time plus randomness. Uniqueness only has to hold per user, and the
    // server scopes the key that way, so this does not need to be a UUID.
    final r = Random();
    final noise = List.generate(
      8,
      (_) => r.nextInt(16).toRadixString(16),
    ).join();
    return '${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}-$noise';
  }
}
