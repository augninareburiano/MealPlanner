import '../models/user_profile.dart';

/// Estimates a daily calorie target from a [UserProfile].
///
/// Uses the Mifflin-St Jeor equation for basal metabolic rate, scaled by an
/// activity factor, then nudged by the user's health goal. Falls back to
/// [defaultTarget] when the profile is missing the numbers needed to compute
/// one (which is the case until the profile form is filled in).
class CalorieCalculator {
  static const int defaultTarget = 2000;

  static int dailyTarget(UserProfile? profile) {
    if (profile == null) return defaultTarget;

    final age = profile.age;
    final weight = profile.weightKg;
    final height = profile.heightCm;
    final gender = profile.gender?.toLowerCase();
    if (age == null || weight == null || height == null || gender == null) {
      return defaultTarget;
    }

    // Mifflin-St Jeor basal metabolic rate.
    final base = (10 * weight) + (6.25 * height) - (5 * age);
    final bmr = gender.startsWith('m') ? base + 5 : base - 161;

    final tdee = bmr * _activityFactor(profile.activityLevel);
    return (tdee + _goalAdjustment(profile.healthGoal)).round();
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
