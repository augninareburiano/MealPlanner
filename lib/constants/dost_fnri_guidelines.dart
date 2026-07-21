/// Dietary reference values published by the Philippine Department of Science
/// and Technology – Food and Nutrition Research Institute (DOST-FNRI).
///
/// The app compares a user's daily intake and generated meal plans against
/// these values to produce nutrition feedback.
///
/// Sources:
///  * Philippine Dietary Reference Intakes (PDRI), DOST-FNRI, 2015 —
///    Acceptable Macronutrient Distribution Ranges (AMDR) and the Estimated
///    Energy Requirement (EER) framework.
///  * Nutritional Guidelines for Filipinos (NGF), DOST-FNRI.
///
/// The macronutrient distribution ranges below are taken directly from the
/// PDRI. The daily energy requirement is *estimated* from the user's profile
/// using the Total Energy Expenditure model the PDRI is built on
/// (Basal Metabolic Rate × Physical Activity Level), because the exact EER for
/// a person depends on their age, sex and activity — data we collect in the
/// user profile.
library;

/// A percentage-of-total-energy range, e.g. carbohydrates should supply
/// 55–75% of daily calories.
class EnergyPercentRange {
  final double lowPercent;
  final double highPercent;

  const EnergyPercentRange(this.lowPercent, this.highPercent);

  double get midPercent => (lowPercent + highPercent) / 2;
}

/// DOST-FNRI dietary guidelines used across the feedback feature.
class DostFnriGuidelines {
  DostFnriGuidelines._();

  // --- Acceptable Macronutrient Distribution Ranges (PDRI 2015) ------------
  // Expressed as a share of total energy intake.

  /// Carbohydrates: 55–75% of total energy.
  static const carbohydratePercent = EnergyPercentRange(55, 75);

  /// Protein: 10–15% of total energy.
  static const proteinPercent = EnergyPercentRange(10, 15);

  /// Total fat (adults ≥19 y): 15–30% of total energy.
  static const fatPercent = EnergyPercentRange(15, 30);

  // --- Other daily reference values ----------------------------------------
  // Used by the nutrition facts panel to express a single food or meal as a
  // share of a day's recommendation.

  /// Dietary fibre for adults: 20–25 g/day (NGF). We compare against the
  /// midpoint, since a facts panel needs one number.
  static const fibreGramsPerDay = 22.5;

  /// Sodium ceiling: 2000 mg/day (≈5 g of salt) — the NGF's "eat less salty
  /// foods" guideline, aligned with the WHO limit.
  static const sodiumMgLimit = 2000.0;

  /// Cholesterol ceiling: 300 mg/day.
  static const cholesterolMgLimit = 300.0;

  /// Saturated fat should supply less than 10% of total energy.
  static const saturatedFatPercentLimit = 10.0;

  /// Free/added sugars should supply less than 10% of total energy.
  static const sugarPercentLimit = 10.0;

  // --- Energy yields (Atwater factors) -------------------------------------

  static const kcalPerGramCarb = 4.0;
  static const kcalPerGramProtein = 4.0;
  static const kcalPerGramFat = 9.0;

  // --- Physical Activity Level (PAL) factors -------------------------------
  // Multipliers applied to Basal Metabolic Rate to estimate Total Energy
  // Expenditure, aligned with the FNRI PDRI activity categories.

  static const palSedentary = 1.2;
  static const palLightlyActive = 1.375;
  static const palModeratelyActive = 1.55;
  static const palVeryActive = 1.725;
  static const palExtraActive = 1.9;

  /// Fallback PAL when the profile's activity level is missing or unknown.
  static const palDefault = palModeratelyActive;

  /// Neutral daily energy target (kcal) used when the profile lacks the data
  /// needed to estimate a personal requirement. Roughly the PDRI reference for
  /// a moderately active adult.
  static const defaultEnergyKcal = 2000.0;

  /// Energy adjustment (kcal/day) applied for a weight-change health goal.
  static const goalEnergyDelta = 500.0;

  /// Lowest daily energy target we will ever recommend, so goal adjustments
  /// never push the target into an unsafe range.
  static const minSafeEnergyKcal = 1200.0;

  /// Half-width of the "on track" band for daily energy, as a fraction of the
  /// target. Intake within ±10% of the target counts as on track.
  static const energyOnTrackTolerance = 0.10;

  /// Maps a free-text activity level from the user profile to a PAL factor.
  /// Matching is case-insensitive and keyword-based so it tolerates the
  /// different labels a profile screen might use.
  static double palForActivityLevel(String? activityLevel) {
    final value = activityLevel?.toLowerCase().trim() ?? '';
    if (value.isEmpty) return palDefault;
    if (value.contains('sedentary')) return palSedentary;
    if (value.contains('extra') || value.contains('athlete')) {
      return palExtraActive;
    }
    if (value.contains('very')) return palVeryActive;
    if (value.contains('moderate')) return palModeratelyActive;
    if (value.contains('light')) return palLightlyActive;
    if (value.contains('active')) return palModeratelyActive;
    return palDefault;
  }
}
