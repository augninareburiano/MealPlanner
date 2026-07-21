import 'daily_nutrition.dart';
import 'nutrition_target.dart';

/// Where a measured value sits relative to its DOST-FNRI recommended range.
enum NutrientStatus { below, onTrack, above }

/// Feedback for one nutrient: how much was consumed, the recommended range,
/// the resulting [status], and a short, plain-language insight.
class NutrientFeedback {
  /// Display label, e.g. `Energy`, `Protein`.
  final String label;

  /// Unit for [consumed] and the range, e.g. `kcal` or `g`.
  final String unit;

  final double consumed;
  final NutrientRange recommended;
  final NutrientStatus status;
  final String insight;

  const NutrientFeedback({
    required this.label,
    required this.unit,
    required this.consumed,
    required this.recommended,
    required this.status,
    required this.insight,
  });

  /// Progress toward the mid-point of the recommended range, clamped to 0–1,
  /// suitable for a progress bar.
  double get progress {
    if (recommended.mid <= 0) return 0;
    final value = consumed / recommended.mid;
    return value.clamp(0.0, 1.0);
  }
}

/// The complete daily nutrition insight shown on the feedback screen:
/// the aggregated intake, the DOST-FNRI target it was compared against,
/// per-nutrient feedback, and an overall headline.
class NutritionFeedback {
  final DailyNutrition intake;
  final NutritionTarget target;
  final NutrientFeedback energy;
  final NutrientFeedback carbs;
  final NutrientFeedback protein;
  final NutrientFeedback fat;

  /// One-line summary of the day, e.g. how balanced the intake was.
  final String headline;

  const NutritionFeedback({
    required this.intake,
    required this.target,
    required this.energy,
    required this.carbs,
    required this.protein,
    required this.fat,
    required this.headline,
  });

  /// The macronutrient rows, in the order they should be displayed.
  List<NutrientFeedback> get macros => [carbs, protein, fat];

  /// Number of nutrients (energy + macros) that fall inside their
  /// recommended range.
  int get onTrackCount =>
      [energy, ...macros].where((n) => n.status == NutrientStatus.onTrack).length;
}
