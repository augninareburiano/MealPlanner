import 'package:flutter_test/flutter_test.dart';

import 'package:foodgapp/models/user_profile.dart';
import 'package:foodgapp/services/daily_budget_calculator.dart';
import 'package:foodgapp/services/reni_reference.dart';

void main() {
  group('calorie target (Mifflin-St Jeor)', () {
    test('maintain: male 30y 80kg 180cm moderate', () {
      // BMR = 10*80 + 6.25*180 - 5*30 + 5 = 1780; ×1.55 = 2759.
      final t = DailyBudgetCalculator.forProfile(
        const UserProfile(
          userId: 'u',
          age: 30,
          gender: 'male',
          weightKg: 80,
          heightCm: 180,
          activityLevel: 'moderate',
          healthGoal: 'maintain',
        ),
      );
      expect(t.calories, 2759);
      expect(t.personalized, isTrue);
    });

    test('lose weight subtracts a 500 kcal deficit', () {
      final base = DailyBudgetCalculator.forProfile(
        const UserProfile(
          userId: 'u',
          age: 30,
          gender: 'male',
          weightKg: 80,
          heightCm: 180,
          activityLevel: 'moderate',
          healthGoal: 'maintain',
        ),
      );
      final lose = DailyBudgetCalculator.forProfile(
        const UserProfile(
          userId: 'u',
          age: 30,
          gender: 'male',
          weightKg: 80,
          heightCm: 180,
          activityLevel: 'moderate',
          healthGoal: 'lose weight',
        ),
      );
      expect(lose.calories, base.calories - 500);
    });

    test('gain muscle adds a 500 kcal surplus', () {
      final gain = DailyBudgetCalculator.forProfile(
        const UserProfile(
          userId: 'u',
          age: 25,
          gender: 'female',
          weightKg: 60,
          heightCm: 165,
          activityLevel: 'active',
          healthGoal: 'gain muscle',
        ),
      );
      final maintain = DailyBudgetCalculator.forProfile(
        const UserProfile(
          userId: 'u',
          age: 25,
          gender: 'female',
          weightKg: 60,
          heightCm: 165,
          activityLevel: 'active',
          healthGoal: 'maintain',
        ),
      );
      expect(gain.calories, maintain.calories + 500);
    });

    test('higher activity level raises the target', () {
      NutrientTargetsCalories factor(String level) => NutrientTargetsCalories(
            DailyBudgetCalculator.forProfile(
              UserProfile(
                userId: 'u',
                age: 30,
                gender: 'male',
                weightKg: 80,
                heightCm: 180,
                activityLevel: level,
                healthGoal: 'maintain',
              ),
            ).calories,
          );

      expect(
        factor('sedentary').calories < factor('moderate').calories,
        isTrue,
      );
      expect(
        factor('moderate').calories < factor('very active').calories,
        isTrue,
      );
    });
  });

  group('incomplete profile falls back to defaults', () {
    test('null profile -> default calories, not personalised', () {
      final t = DailyBudgetCalculator.forProfile(null);
      expect(t.calories, DailyBudgetCalculator.defaultCalories);
      expect(t.personalized, isFalse);
    });

    test('missing weight/height -> default calories', () {
      final t = DailyBudgetCalculator.forProfile(
        const UserProfile(userId: 'u', age: 30, gender: 'male'),
      );
      expect(t.calories, DailyBudgetCalculator.defaultCalories);
      expect(t.personalized, isFalse);
    });
  });

  group('macro split (Philippine AMDR)', () {
    test('carbs 60% and fat 25% of energy; protein at least RENI floor', () {
      const profile = UserProfile(
        userId: 'u',
        age: 30,
        gender: 'male',
        weightKg: 80,
        heightCm: 180,
        activityLevel: 'moderate',
        healthGoal: 'maintain',
      );
      final t = DailyBudgetCalculator.forProfile(profile);

      expect(t.carbsG, closeTo(t.calories * 0.60 / 4, 0.001));
      expect(t.fatG, closeTo(t.calories * 0.25 / 9, 0.001));

      final proteinFromEnergy = t.calories * 0.15 / 4;
      final reni = ReniReference.lookup(gender: 'male', age: 30);
      expect(t.proteinG, greaterThanOrEqualTo(reni.proteinG));
      expect(t.proteinG, greaterThanOrEqualTo(proteinFromEnergy));
    });
  });

  group('RENI micronutrients', () {
    test('menstruating women get a higher iron target than men', () {
      final woman = DailyBudgetCalculator.forProfile(
        const UserProfile(
          userId: 'u',
          age: 30,
          gender: 'female',
          weightKg: 60,
          heightCm: 165,
        ),
      );
      final man = DailyBudgetCalculator.forProfile(
        const UserProfile(
          userId: 'u',
          age: 30,
          gender: 'male',
          weightKg: 80,
          heightCm: 180,
        ),
      );
      expect(woman.ironMg, greaterThan(man.ironMg));
    });

    test('targets carry RENI micronutrient values for the bracket', () {
      final t = DailyBudgetCalculator.forProfile(
        const UserProfile(
          userId: 'u',
          age: 30,
          gender: 'female',
          weightKg: 60,
          heightCm: 165,
        ),
      );
      final reni = ReniReference.lookup(gender: 'female', age: 30);
      expect(t.calciumMg, reni.calciumMg);
      expect(t.vitaminCMg, reni.vitaminCMg);
      expect(t.vitaminARaeUg, reni.vitaminARaeUg);
      expect(t.fiberG, reni.fiberG);
    });

    test('lookup resolves the right age bracket', () {
      final young = ReniReference.lookup(gender: 'female', age: 25);
      final older = ReniReference.lookup(gender: 'female', age: 70);
      // Iron drops after menopause in the reference table.
      expect(young.ironMg, greaterThan(older.ironMg));
    });
  });
}

/// Tiny wrapper to make the activity-comparison test read clearly.
class NutrientTargetsCalories {
  const NutrientTargetsCalories(this.calories);
  final int calories;
}
