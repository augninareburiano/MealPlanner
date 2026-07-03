/// A user's computed daily targets: their calorie budget plus macro and key
/// micronutrient goals.
///
/// Produced by `DailyBudgetCalculator` from a `UserProfile`. Macro grams come
/// from the calorie target via the Philippine AMDR split; micronutrient goals
/// come from the DOST-FNRI RENI reference values for the user's sex and age.
class NutrientTargets {
  /// Daily energy target, in kcal.
  final int calories;

  // Macronutrients, in grams/day.
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;

  // Key micronutrients (RENI), in their conventional units.
  final double calciumMg;
  final double ironMg;
  final double vitaminCMg;
  final double vitaminARaeUg;

  /// False when the profile lacked age/sex/weight/height, so default (adult
  /// reference) values were used instead of a personalised calculation.
  final bool personalized;

  const NutrientTargets({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.calciumMg,
    required this.ironMg,
    required this.vitaminCMg,
    required this.vitaminARaeUg,
    required this.personalized,
  });

  @override
  bool operator ==(Object other) =>
      other is NutrientTargets &&
      other.calories == calories &&
      other.proteinG == proteinG &&
      other.carbsG == carbsG &&
      other.fatG == fatG &&
      other.fiberG == fiberG &&
      other.calciumMg == calciumMg &&
      other.ironMg == ironMg &&
      other.vitaminCMg == vitaminCMg &&
      other.vitaminARaeUg == vitaminARaeUg &&
      other.personalized == personalized;

  @override
  int get hashCode => Object.hash(
        calories,
        proteinG,
        carbsG,
        fatG,
        fiberG,
        calciumMg,
        ironMg,
        vitaminCMg,
        vitaminARaeUg,
        personalized,
      );
}
