import 'package:flutter_test/flutter_test.dart';
import 'package:foodgapp/models/daily_nutrition.dart';
import 'package:foodgapp/models/meal_log.dart';
import 'package:foodgapp/models/nutrition_feedback.dart';
import 'package:foodgapp/models/user_profile.dart';
import 'package:foodgapp/services/nutrition_feedback_service.dart';

DailyNutrition intake({
  double calories = 0,
  double protein = 0,
  double carbs = 0,
  double fat = 0,
  int mealCount = 1,
}) =>
    DailyNutrition(
      mealDate: '2026-07-21',
      mealCount: mealCount,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );

void main() {
  group('buildTarget', () {
    test('falls back to DOST-FNRI defaults when profile is null', () {
      final target = NutritionFeedbackService.buildTarget(null);

      expect(target.fromDefaults, isTrue);
      expect(target.energyKcal, 2000);
      // AMDR of a 2000 kcal day: carbs 55–75% at 4 kcal/g -> 275–375 g.
      expect(target.carbsGrams.low, closeTo(275, 0.1));
      expect(target.carbsGrams.high, closeTo(375, 0.1));
      // Protein 10–15% at 4 kcal/g -> 50–75 g.
      expect(target.proteinGrams.low, closeTo(50, 0.1));
      expect(target.proteinGrams.high, closeTo(75, 0.1));
      // Fat 15–30% at 9 kcal/g -> ~33.3–66.7 g.
      expect(target.fatGrams.low, closeTo(33.33, 0.1));
      expect(target.fatGrams.high, closeTo(66.67, 0.1));
    });

    test('personalises energy from a complete profile', () {
      const profile = UserProfile(
        userId: 'u1',
        age: 25,
        gender: 'male',
        heightCm: 175,
        weightKg: 70,
        activityLevel: 'Moderately active',
      );

      final target = NutritionFeedbackService.buildTarget(profile);

      expect(target.fromDefaults, isFalse);
      // Mifflin–St Jeor BMR: 10*70 + 6.25*175 - 5*25 + 5 = 1673.75
      // TEE = 1673.75 * 1.55 (moderate) = ~2594 kcal.
      expect(target.energyKcal, closeTo(2594.3, 1));
    });

    test('never recommends below the safe energy floor', () {
      const profile = UserProfile(
        userId: 'u2',
        age: 80,
        gender: 'female',
        heightCm: 150,
        weightKg: 45,
        activityLevel: 'Sedentary',
        healthGoal: 'Lose weight',
      );

      final target = NutritionFeedbackService.buildTarget(profile);
      expect(target.energyKcal, greaterThanOrEqualTo(1200));
    });
  });

  group('buildFeedback', () {
    test('flags an empty day and gives a prompt to log a meal', () {
      final feedback = NutritionFeedbackService.buildFeedback(
        profile: null,
        intake: intake(mealCount: 0),
      );

      expect(feedback.intake.isEmpty, isTrue);
      expect(feedback.headline, contains('No meals logged'));
      expect(feedback.energy.status, NutrientStatus.below);
    });

    test('marks a balanced day as fully on track', () {
      final feedback = NutritionFeedbackService.buildFeedback(
        profile: null,
        intake: intake(calories: 2000, carbs: 300, protein: 60, fat: 50),
      );

      expect(feedback.energy.status, NutrientStatus.onTrack);
      expect(feedback.carbs.status, NutrientStatus.onTrack);
      expect(feedback.protein.status, NutrientStatus.onTrack);
      expect(feedback.fat.status, NutrientStatus.onTrack);
      expect(feedback.onTrackCount, 4);
      expect(feedback.headline, contains('Great balance'));
    });

    test('detects intake above and below the recommended ranges', () {
      final feedback = NutritionFeedbackService.buildFeedback(
        profile: null,
        // Way over energy/carbs, far under protein.
        intake: intake(calories: 3200, carbs: 500, protein: 20, fat: 50),
      );

      expect(feedback.energy.status, NutrientStatus.above);
      expect(feedback.carbs.status, NutrientStatus.above);
      expect(feedback.protein.status, NutrientStatus.below);
      expect(feedback.protein.insight, contains('DOST-FNRI'));
    });

    test('progress is clamped to the 0–1 range', () {
      final feedback = NutritionFeedbackService.buildFeedback(
        profile: null,
        intake: intake(calories: 9999, carbs: 999, protein: 999, fat: 999),
      );
      for (final n in [feedback.energy, ...feedback.macros]) {
        expect(n.progress, inInclusiveRange(0.0, 1.0));
      }
    });
  });

  group('DailyNutrition.fromLogs', () {
    test('sums logs and treats missing macros as zero', () {
      final logs = [
        const MealLog(
          userId: 'u1',
          mealDate: '2026-07-21',
          mealType: 'breakfast',
          foodName: 'Rice',
          calories: 200,
          carbs: 45,
        ),
        const MealLog(
          userId: 'u1',
          mealDate: '2026-07-21',
          mealType: 'lunch',
          foodName: 'Fish',
          calories: 150,
          protein: 25,
          fat: 5,
        ),
      ];

      final total = DailyNutrition.fromLogs('2026-07-21', logs);
      expect(total.mealCount, 2);
      expect(total.calories, 350);
      expect(total.carbs, 45);
      expect(total.protein, 25);
      expect(total.fat, 5);
    });
  });
}
