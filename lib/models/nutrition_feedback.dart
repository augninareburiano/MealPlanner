/// Result types for the daily nutrition feedback system.
///
/// Produced by `NutritionFeedbackEngine` by comparing what the user logged on a
/// given day against their `NutrientTargets` (which are themselves derived from
/// the DOST-FNRI RENI/PDRI tables). Pure data — no formatting or UI decisions
/// live here beyond the plain-language strings the engine writes.
library;

/// Where a day's intake of one nutrient sits relative to its target.
enum NutrientStatus {
  /// Meaningfully below target.
  under,

  /// Within the acceptable band around target.
  onTrack,

  /// Meaningfully above target.
  over,
}

/// How a piece of advice should read: a win, a nudge, or neutral context.
enum InsightTone { positive, warning, info }

/// One nutrient's intake for a day, compared against its daily target.
class NutrientAssessment {
  /// Display name, e.g. `Protein`.
  final String label;

  /// Total logged for the day, in [unit].
  final double consumed;

  /// The day's target, in [unit].
  final double target;

  /// Conventional unit for this nutrient, e.g. `g` or `kcal`.
  final String unit;

  final NutrientStatus status;

  const NutrientAssessment({
    required this.label,
    required this.consumed,
    required this.target,
    required this.unit,
    required this.status,
  });

  /// Fraction of the target met — 1.0 is exactly on target. 0 when there is no
  /// usable target to divide by.
  double get ratio => target <= 0 ? 0 : consumed / target;

  /// Signed gap against the target, in [unit]: negative is a shortfall,
  /// positive is an excess.
  double get difference => consumed - target;

  /// [ratio] clamped to 0..1, for progress bars.
  double get progress => ratio.clamp(0.0, 1.0);
}

/// A single piece of plain-language advice about the day.
class Insight {
  /// Short headline, e.g. `Protein is a little low`.
  final String title;

  /// One or two sentences of explanation and a concrete suggestion.
  final String body;

  final InsightTone tone;

  const Insight({
    required this.title,
    required this.body,
    required this.tone,
  });
}

/// Everything the feedback system concluded about one day.
class DailyFeedback {
  /// Energy intake vs the daily calorie budget.
  final NutrientAssessment calories;

  /// Protein, carbohydrate and fat, in that order.
  final List<NutrientAssessment> macros;

  /// Advice for the day, most important first.
  final List<Insight> insights;

  /// How many food items were logged. Zero means the day is untouched.
  final int itemsLogged;

  /// Mirrors `NutrientTargets.personalized` — false when the targets are
  /// generic defaults because the profile is incomplete.
  final bool personalized;

  const DailyFeedback({
    required this.calories,
    required this.macros,
    required this.insights,
    required this.itemsLogged,
    required this.personalized,
  });

  /// True once there is something to assess.
  bool get hasData => itemsLogged > 0;

  /// Calories plus every macro, for callers that render them uniformly.
  List<NutrientAssessment> get all => [calories, ...macros];

  /// True when energy and all macros sit inside their acceptable bands.
  bool get allOnTrack =>
      hasData && all.every((a) => a.status == NutrientStatus.onTrack);
}
