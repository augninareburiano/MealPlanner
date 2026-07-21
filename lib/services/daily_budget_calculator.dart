import 'dart:math';

import '../models/nutrient_targets.dart';
import '../models/user_profile.dart';
import 'reni_reference.dart';

/// Works out a user's daily calorie and nutrient targets from their profile.
///
/// Pure and stateless — the same profile always yields the same
/// [NutrientTargets], which is what lets targets recompute automatically
/// whenever the profile changes.
///
/// Method:
///  * Calories: Mifflin-St Jeor basal metabolic rate × an activity factor,
///    then adjusted for the user's goal (lose / maintain / gain).
///  * Macros: split the calorie target using the Philippine AMDR
///    (protein 15%, carbohydrate 60%, fat 25% of energy), with protein raised
///    to the RENI floor if that is higher.
///  * Micronutrients: taken from the DOST-FNRI RENI values for the user's sex
///    and age (see [ReniReference]).
class DailyBudgetCalculator {
  const DailyBudgetCalculator._();

  /// Calorie target used when the profile is too incomplete to personalise.
  static const int defaultCalories = 2000;

  // Philippine AMDR energy split (fractions of total energy).
  static const double _proteinEnergyShare = 0.15;
  static const double _carbEnergyShare = 0.60;
  static const double _fatEnergyShare = 0.25;

  // Energy per gram (Atwater factors).
  static const double _kcalPerGramProtein = 4;
  static const double _kcalPerGramCarb = 4;
  static const double _kcalPerGramFat = 9;

  static NutrientTargets forProfile(UserProfile? profile) {
    final calories = _calorieTarget(profile);
    final reni = ReniReference.lookup(
      gender: profile?.gender,
      age: profile?.age,
    );

    final proteinFromEnergy =
        calories * _proteinEnergyShare / _kcalPerGramProtein;

    return NutrientTargets(
      calories: calories,
      // Never fall below the RENI protein reference.
      proteinG: max(proteinFromEnergy, reni.proteinG),
      carbsG: calories * _carbEnergyShare / _kcalPerGramCarb,
      fatG: calories * _fatEnergyShare / _kcalPerGramFat,
      fiberG: reni.fiberG,
      calciumMg: reni.calciumMg,
      ironMg: reni.ironMg,
      vitaminCMg: reni.vitaminCMg,
      vitaminARaeUg: reni.vitaminARaeUg,
      personalized: _isComplete(profile),
    );
  }

  static bool _isComplete(UserProfile? p) =>
      p != null &&
      p.age != null &&
      p.gender != null &&
      p.weightKg != null &&
      p.heightCm != null;

  static int _calorieTarget(UserProfile? profile) {
    if (!_isComplete(profile)) return defaultCalories;

    final p = profile!;
    // Mifflin-St Jeor basal metabolic rate.
    final base = (10 * p.weightKg!) + (6.25 * p.heightCm!) - (5 * p.age!);
    final bmr = p.gender!.toLowerCase().startsWith('m') ? base + 5 : base - 161;

    final tdee = bmr * _activityFactor(p.activityLevel);
    return (tdee + _goalAdjustment(p.healthGoal)).round();
  }

  static double _activityFactor(String? activityLevel) {
    switch (activityLevel?.toLowerCase()) {
      case 'light':
      case 'lightly active':
        return 1.375;
      case 'moderate':
      case 'moderately active':
        return 1.55;
      case 'active':
      case 'very active':
        return 1.725;
      case 'extra active':
        return 1.9;
      case 'sedentary':
      default:
        return 1.2;
    }
  }

  static double _goalAdjustment(String? healthGoal) {
    switch (healthGoal?.toLowerCase()) {
      case 'lose weight':
      case 'weight loss':
        return -500;
      case 'gain weight':
      case 'weight gain':
      case 'gain muscle':
        return 500;
      default:
        return 0;
    }
  }
}
