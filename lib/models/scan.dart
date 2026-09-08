import '../theme/ayna_tokens.dart' show Severity;

/// Where a scan is. Mirrors `ScanStatus.status` in `api/openapi.yaml`.
enum ScanState { processing, completed, rejected, failed }

/// The named step the backend is on.
///
/// These exist so the analysing screen can say what is happening rather than
/// spin. The contract's own words: a spinner makes eight seconds feel like
/// thirty; named progress does not.
enum ScanStage {
  received,
  qualityChecked,
  scoring,
  writingReport;

  static ScanStage? parse(String? s) => switch (s) {
    'received' => received,
    'quality_checked' => qualityChecked,
    'scoring' => scoring,
    'writing_report' => writingReport,
    _ => null,
  };

  /// Present tense, first person plural, and specific. "Processing" tells the
  /// user nothing they did not already know from the fact that they are
  /// waiting.
  String get label => switch (this) {
    received => 'Got your photo',
    qualityChecked => 'Checking the light and focus',
    scoring => 'Reading six things in your skin',
    writingReport => 'Just finishing up',
  };

  /// Roughly how far through the whole job this step sits. Used to pace the
  /// bar between server updates — never to claim completion.
  double get progress => switch (this) {
    received => 0.12,
    qualityChecked => 0.34,
    scoring => 0.72,
    writingReport => 0.93,
  };
}

/// Why a photo was refused. Every one of these is the user's to fix, which is
/// why each maps to an instruction rather than an error code.
enum RejectionReason {
  blurry,
  tooDark,
  noFaceDetected,
  faceTooSmall,
  occluded;

  static RejectionReason? parse(String? s) => switch (s) {
    'blurry' => blurry,
    'too_dark' => tooDark,
    'no_face_detected' => noFaceDetected,
    'face_too_small' => faceTooSmall,
    'occluded' => occluded,
    _ => null,
  };

  String get title => switch (this) {
    blurry => 'That one came out blurry',
    tooDark => 'Not quite enough light',
    noFaceDetected => 'No face in the frame',
    faceTooSmall => 'A little too far away',
    occluded => 'Something is covering your face',
  };

  String get advice => switch (this) {
    blurry => 'Rest your elbow on something and hold still for a moment.',
    tooDark => 'Face a window if you can. Daylight beats a ceiling light.',
    noFaceDetected => 'Line your face up inside the oval and try once more.',
    faceTooSmall => 'Bring the phone closer, until your face fills the oval.',
    occluded => 'Push your hair back and take off glasses if you can.',
  };
}

enum IssueType {
  acne,
  redness,
  dryness,
  darkSpots,
  texture,
  pores;

  static IssueType? parse(String s) => switch (s) {
    'acne' => acne,
    'redness' => redness,
    'dryness' => dryness,
    'dark_spots' => darkSpots,
    'texture' => texture,
    'pores' => pores,
    _ => null,
  };

  String get label => switch (this) {
    acne => 'Breakouts',
    redness => 'Redness',
    dryness => 'Dryness',
    darkSpots => 'Dark spots',
    texture => 'Texture',
    pores => 'Pores',
  };
}

Severity _severity(String s) => switch (s) {
  'none' => Severity.none,
  'mild' => Severity.mild,
  'moderate' => Severity.moderate,
  'severe' => Severity.severe,
  _ => Severity.unknown,
};

class ScanIssue {
  const ScanIssue({
    required this.type,
    required this.severity,
    required this.severityLevels,
    this.score,
    this.confidence,
  });

  final IssueType type;
  final Severity severity;

  /// Problem magnitude, 0–100, **higher is worse** — the opposite of the
  /// vendor's own scale. The server does the inversion so the client never
  /// has to know which way a particular vendor counts.
  final int? score;

  final double? confidence;

  /// How many levels the underlying source can actually distinguish.
  ///
  /// The spike is the reason this is on the wire at all: one AILab endpoint
  /// returns 0–100 scores (four levels) and the other returns presence flags
  /// (two). **A four-step bar drawn for a two-level signal is a lie about
  /// precision**, so the client must render differently rather than assume.
  final int severityLevels;

  bool get isUnknown => severity == Severity.unknown;

  factory ScanIssue.fromJson(Map<String, dynamic> j) => ScanIssue(
    type: IssueType.parse(j['type'] as String) ?? IssueType.acne,
    severity: _severity(j['severity'] as String),
    score: j['score'] as int?,
    confidence: (j['confidence'] as num?)?.toDouble(),
    severityLevels: j['severityLevels'] as int? ?? 4,
  );
}

class SkinReport {
  const SkinReport({
    required this.scanId,
    required this.overallScore,
    required this.issues,
    required this.disclaimer,
    required this.rulesetVersion,
    required this.generatedAt,
    this.skinAge,
    this.chronologicalAge,
    this.heatmapUrl,
    this.photoUrl,
    this.tipHeadline,
    this.tipBody,
  });

  final String scanId;

  /// 0–100, higher is better. Rescaled server-side from the vendor's narrower
  /// band so the full range is usable.
  final int overallScore;

  /// Null on tiers without a reading. **Render the absence** — never fall back
  /// to chronological age, which reads as "right in step" and is a fabrication.
  final int? skinAge;
  final int? chronologicalAge;

  final List<ScanIssue> issues;
  final String? heatmapUrl;
  final String? photoUrl;
  final String? tipHeadline;
  final String? tipBody;

  /// Which `SeverityRuleSet` produced these severities (PD-2). Stamped so the
  /// question "why did it say that in March but not in June?" is answerable.
  final String rulesetVersion;

  /// Server-supplied so the wording can be corrected without a release, and
  /// **must be displayed** (NFR-6).
  final String disclaimer;

  final DateTime generatedAt;

  int? get skinAgeDelta => skinAge == null || chronologicalAge == null
      ? null
      : chronologicalAge! - skinAge!;

  factory SkinReport.fromJson(Map<String, dynamic> j) => SkinReport(
    scanId: j['scanId'] as String,
    overallScore: j['overallScore'] as int,
    skinAge: j['skinAge'] as int?,
    chronologicalAge: j['chronologicalAge'] as int?,
    issues: (j['issues'] as List)
        .map((e) => ScanIssue.fromJson(e as Map<String, dynamic>))
        .toList(),
    heatmapUrl: j['heatmapUrl'] as String?,
    photoUrl: j['photoUrl'] as String?,
    tipHeadline: (j['tip'] as Map<String, dynamic>?)?['headline'] as String?,
    tipBody: (j['tip'] as Map<String, dynamic>?)?['body'] as String?,
    rulesetVersion: j['rulesetVersion'] as String,
    disclaimer: j['disclaimer'] as String,
    generatedAt: DateTime.parse(j['generatedAt'] as String),
  );
}

class ScanProgress {
  const ScanProgress({
    required this.scanId,
    required this.state,
    required this.allowanceSpent,
    this.stage,
    this.rejectionReason,
    this.estimatedSeconds,
  });

  final String scanId;
  final ScanState state;
  final ScanStage? stage;

  /// **False for a rejection.** The vendor does not bill a failed request, so
  /// a blurry photo must not cost the user one of their weekly scans.
  final bool allowanceSpent;

  final RejectionReason? rejectionReason;
  final int? estimatedSeconds;

  bool get isDone => state != ScanState.processing;

  factory ScanProgress.fromJson(Map<String, dynamic> j) => ScanProgress(
    scanId: j['scanId'] as String,
    state: switch (j['status'] as String) {
      'completed' => ScanState.completed,
      'rejected' => ScanState.rejected,
      'failed' => ScanState.failed,
      _ => ScanState.processing,
    },
    stage: ScanStage.parse(j['stage'] as String?),
    allowanceSpent: j['allowanceSpent'] as bool? ?? false,
    rejectionReason: RejectionReason.parse(j['rejectionReason'] as String?),
    estimatedSeconds: j['estimatedSeconds'] as int?,
  );
}

/// A row in the history list.
///
/// Deliberately not a full [SkinReport]. A list of twenty reports is twenty
/// times the payload for six fields nobody reads until they tap through, and on
/// the connections this product assumes that difference is seconds.
class ScanSummary {
  const ScanSummary({
    required this.scanId,
    required this.state,
    required this.submittedAt,
    required this.allowanceSpent,
    this.overallScore,
    this.skinAge,
    this.rejectionReason,
  });

  final String scanId;
  final ScanState state;
  final DateTime submittedAt;
  final bool allowanceSpent;

  /// Null unless the scan completed. A row must be able to say "no result"
  /// without showing a zero that reads like a score.
  final int? overallScore;
  final int? skinAge;
  final RejectionReason? rejectionReason;

  bool get hasResult => state == ScanState.completed && overallScore != null;

  factory ScanSummary.fromJson(Map<String, dynamic> j) => ScanSummary(
    scanId: j['scanId'] as String,
    state: switch (j['status'] as String) {
      'completed' => ScanState.completed,
      'rejected' => ScanState.rejected,
      'failed' => ScanState.failed,
      _ => ScanState.processing,
    },
    submittedAt: DateTime.parse(j['submittedAt'] as String).toLocal(),
    allowanceSpent: j['allowanceSpent'] as bool? ?? false,
    overallScore: j['overallScore'] as int?,
    skinAge: j['skinAge'] as int?,
    rejectionReason: RejectionReason.parse(j['rejectionReason'] as String?),
  );
}

/// One week on the trend chart (FR-8).
class TrendPoint {
  const TrendPoint({
    required this.weekStart,
    required this.overallScore,
    this.skinAge,
  });

  final DateTime weekStart;
  final int overallScore;
  final int? skinAge;

  factory TrendPoint.fromJson(Map<String, dynamic> j) => TrendPoint(
    weekStart: DateTime.parse(j['weekStart'] as String),
    overallScore: j['overallScore'] as int,
    skinAge: j['skinAge'] as int?,
  );
}

class Trend {
  const Trend({
    required this.points,
    required this.truncated,
    required this.totalAvailable,
  });

  final List<TrendPoint> points;

  /// True when entitlement limited the window.
  final bool truncated;

  /// How many weeks exist in total. Sent so the client can say what is behind
  /// the paywall rather than pretending nothing is.
  final int totalAvailable;

  bool get isEmpty => points.isEmpty;

  /// A trend needs two points to be a trend. One is just a reading.
  bool get hasTrend => points.length >= 2;

  factory Trend.fromJson(Map<String, dynamic> j) => Trend(
    points: ((j['points'] as List?) ?? [])
        .map((e) => TrendPoint.fromJson(e as Map<String, dynamic>))
        .toList(),
    truncated: j['truncated'] as bool? ?? false,
    totalAvailable: j['totalAvailable'] as int? ?? 0,
  );
}
