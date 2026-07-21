/// Recommended intake ranges for one day, derived from DOST-FNRI guidelines
/// and the user's profile. Grams are computed from the AMDR percentages and
/// the user's estimated energy requirement.
class NutrientRange {
  final double low;
  final double high;

  const NutrientRange(this.low, this.high);

  double get mid => (low + high) / 2;
}

/// A person's recommended daily nutrition, produced by comparing DOST-FNRI
/// guidelines against their profile.
class NutritionTarget {
  /// Estimated daily energy requirement, in kilocalories.
  final double energyKcal;

  /// Recommended grams per day for each macronutrient (from the AMDR ranges).
  final NutrientRange carbsGrams;
  final NutrientRange proteinGrams;
  final NutrientRange fatGrams;

  /// True when the target was built from DOST-FNRI defaults because the
  /// profile lacked the age/sex/height/weight needed to personalise it.
  final bool fromDefaults;

  const NutritionTarget({
    required this.energyKcal,
    required this.carbsGrams,
    required this.proteinGrams,
    required this.fatGrams,
    required this.fromDefaults,
  });

  /// Lower and upper energy bounds of the "on track" band, in kcal.
  NutrientRange energyBand(double tolerance) => NutrientRange(
        energyKcal * (1 - tolerance),
        energyKcal * (1 + tolerance),
      );
}
