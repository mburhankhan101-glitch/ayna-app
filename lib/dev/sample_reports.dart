import '../models/scan.dart';
import '../theme/ayna_tokens.dart' show Severity;

/// Fixtures for designing result screens without spending a scan.
///
/// Every real scan costs a paid vendor call and one of the user's weekly
/// allowance, so iterating on this screen against live data is the most
/// expensive possible way to move a box four pixels. These are shaped from an
/// actual response, not invented, so the layout is exercised against numbers
/// the product really produces.
abstract final class SampleReports {
  static ScanIssue _issue(IssueType t, Severity s, int? score) =>
      ScanIssue(type: t, severity: s, score: score, severityLevels: 4);

  /// The real 2026-08-30 scan: a high score with two mild concerns.
  static SkinReport get clear => SkinReport(
    scanId: 'scn_sample_clear',
    overallScore: 30,
    skinAge: 25,
    chronologicalAge: 26,
    issues: [
      _issue(IssueType.acne, Severity.none, 2),
      _issue(IssueType.redness, Severity.none, 5),
      _issue(IssueType.dryness, Severity.none, 1),
      _issue(IssueType.darkSpots, Severity.mild, 15),
      _issue(IssueType.texture, Severity.mild, 11),
      _issue(IssueType.pores, Severity.none, 3),
    ],
    rulesetVersion: 'ailab-pro-degree-2026-08-24',
    disclaimer:
        'Ayna gives you an impression of your skin, not a diagnosis. '
        'For anything that worries you, see a dermatologist.',
    generatedAt: DateTime(2026, 8, 30, 15, 41),
  );

  /// Something to actually act on — exercises the severe path and the layout
  /// with a long concern label at the top.
  static SkinReport get concerns => SkinReport(
    scanId: 'scn_sample_concerns',
    overallScore: 62,
    skinAge: 31,
    chronologicalAge: 26,
    issues: [
      _issue(IssueType.acne, Severity.severe, 71),
      _issue(IssueType.redness, Severity.moderate, 48),
      _issue(IssueType.dryness, Severity.mild, 22),
      _issue(IssueType.darkSpots, Severity.moderate, 44),
      _issue(IssueType.texture, Severity.mild, 19),
      _issue(IssueType.pores, Severity.none, 6),
    ],
    rulesetVersion: 'ailab-pro-degree-2026-08-24',
    disclaimer:
        'Ayna gives you an impression of your skin, not a diagnosis. '
        'For anything that worries you, see a dermatologist.',
    generatedAt: DateTime(2026, 8, 30, 15, 41),
  );

  /// A free-tier report and an unmeasurable concern in one: no skin age, and
  /// redness the vendor could not assess. Both must render as absences rather
  /// than as zeroes.
  static SkinReport get partial => SkinReport(
    scanId: 'scn_sample_partial',
    overallScore: 44,
    issues: [
      _issue(IssueType.acne, Severity.mild, 24),
      _issue(IssueType.redness, Severity.unknown, null),
      _issue(IssueType.dryness, Severity.moderate, 41),
      _issue(IssueType.darkSpots, Severity.mild, 18),
      _issue(IssueType.texture, Severity.none, 7),
      _issue(IssueType.pores, Severity.mild, 21),
    ],
    rulesetVersion: 'ailab-pro-degree-2026-08-24',
    disclaimer:
        'Ayna gives you an impression of your skin, not a diagnosis. '
        'For anything that worries you, see a dermatologist.',
    generatedAt: DateTime(2026, 8, 30, 15, 41),
  );
}
