/// Typed models for the API's user payload.
///
/// Parsed into real types rather than passed around as `Map<String, dynamic>`
/// so a field the server renamed fails here, at one place, with a message —
/// instead of surfacing three screens later as a silent null.
///
/// These mirror `api/openapi.yaml`. When that file changes, this changes.
library;

class Entitlement {
  const Entitlement({
    required this.tier,
    required this.scansRemaining,
    required this.periodResetsAt,
    required this.hasHeatmap,
    required this.hasSkinAge,
  });

  final String tier;
  final int scansRemaining;
  final DateTime? periodResetsAt;

  /// Read as explicit capability flags, never inferred from [tier].
  ///
  /// A client that maps tiers to features itself goes stale the moment pricing
  /// changes — and then renders an empty heatmap slot, or hides one the user
  /// has paid for.
  final bool hasHeatmap;
  final bool hasSkinAge;

  bool get isFree => tier == 'free';

  /// Whether a scan can be taken right now. The server is the authority; this
  /// only decides whether the button looks enabled.
  bool get canScan => scansRemaining > 0;

  factory Entitlement.fromJson(Map<String, dynamic> json) => Entitlement(
    tier: json['tier'] as String? ?? 'free',
    scansRemaining: json['scansRemaining'] as int? ?? 0,
    periodResetsAt: DateTime.tryParse(json['periodResetsAt'] as String? ?? ''),
    hasHeatmap: json['hasHeatmap'] as bool? ?? false,
    hasSkinAge: json['hasSkinAge'] as bool? ?? false,
  );
}

class AynaUser {
  const AynaUser({
    required this.id,
    required this.birthYear,
    required this.timezone,
    required this.hasConsent,
    required this.entitlement,
    required this.streakWeeks,
    this.displayName,
    this.photoRetentionDays,
  });

  final String id;
  final String? displayName;
  final int birthYear;
  final String timezone;

  /// Whether consent exists for the policy version currently in force.
  ///
  /// Version-scoped on the server, so this can flip back to false when the
  /// wording changes — which is the point. The app must re-ask rather than
  /// assume a past agreement covers new terms.
  final bool hasConsent;

  final Entitlement entitlement;
  final int streakWeeks;

  /// How long photos are kept, in days, or null for indefinitely (NFR-4).
  ///
  /// Null is a real choice here, not a missing value. A user who picked "keep
  /// them" and a server that failed to send the field are indistinguishable in
  /// this type, which is acceptable only because the settings screen renders
  /// both the same way: as the "Keep them" option selected.
  final int? photoRetentionDays;

  /// Chronological age, for the skin-age comparison (FR-5).
  ///
  /// Derived from the year alone because that is all the server stores (PD-1),
  /// so it treats everyone as born on 1 January. Same approximation the age
  /// gate uses, and the same reason: a full date of birth is meaningfully more
  /// identifying for no added benefit.
  int get age => DateTime.now().year - birthYear;

  /// A name to greet with, or null when there is nothing worth using.
  String? get firstName {
    final name = displayName?.trim();
    if (name == null || name.isEmpty) return null;
    return name.split(' ').first;
  }

  factory AynaUser.fromJson(Map<String, dynamic> json) => AynaUser(
    id: json['id'] as String,
    displayName: json['displayName'] as String?,
    birthYear: json['birthYear'] as int,
    timezone: json['timezone'] as String? ?? 'UTC',
    hasConsent: json['hasConsent'] as bool? ?? false,
    entitlement: Entitlement.fromJson(
      (json['entitlement'] as Map<String, dynamic>?) ?? const {},
    ),
    streakWeeks: json['streakWeeks'] as int? ?? 0,
    photoRetentionDays: json['photoRetentionDays'] as int?,
  );
}
