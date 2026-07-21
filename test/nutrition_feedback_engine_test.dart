import 'package:flutter_test/flutter_test.dart';

import 'package:foodgapp/models/meal_log.dart';
import 'package:foodgapp/models/nutrient_targets.dart';
import 'package:foodgapp/models/nutrition_feedback.dart';
import 'package:foodgapp/services/nutrition_feedback_engine.dart';

/// A 2000 kcal target using the Philippine AMDR split the calculator applies:
/// protein 15% (75 g), carbs 60% (300 g), fat 25% (~56 g).
NutrientTargets targets({bool personalized = true}) => NutrientTargets(
      calories: 2000,
      proteinG: 75,
      carbsG: 300,
      fatG: 55.6,
      fiberG: 25,
      calciumMg: 750,
      ironMg: 28,
      vitaminCMg: 60,
      vitaminARaeUg: 500,
      personalized: personalized,
    );

/// A single logged item; macros default to null to exercise the null handling.
MealLog log({
  double? calories,
  double? protein,
  double? carbs,
  double? fat,
}) =>
    MealLog(
      userId: 'u',
      mealDate: '2026-07-20',
      mealType: 'lunch',
      foodName: 'test food',
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );

/// Titles of the insights produced, for concise assertions.
List<String> titles(DailyFeedback f) => f.insights.map((i) => i.title).toList();

bool hasTitle(DailyFeedback f, String needle) =>
    titles(f).any((t) => t.toLowerCase().contains(needle.toLowerCase()));

void main() {
  group('empty day', () {
    test('reports no data and prompts the user to log', () {
      final f = NutritionFeedbackEngine.evaluate(
        targets: targets(),
        logs: const [],
      );

      expect(f.hasData, isFalse);
      expect(f.itemsLogged, 0);
      expect(f.insights, hasLength(1));
      expect(f.insights.single.tone, InsightTone.info);
      expect(hasTitle(f, 'Nothing logged'), isTrue);
    });

    test('still exposes zeroed assessments against the targets', () {
      final f = NutritionFeedbackEngine.evaluate(
        targets: targets(),
        logs: const [],
      );

      expect(f.calories.consumed, 0);
      expect(f.calories.target, 2000);
      expect(f.macros.map((m) => m.label), ['Protein', 'Carbs', 'Fat']);
    });
  });

  group('a day that meets the guidelines', () {
    // Exactly on target: 300 kcal protein (15%), 1200 carb (60%), 500 fat (25%).
    final onTarget = [log(calories: 2000, protein: 75, carbs: 300, fat: 55.6)];

    test('marks every nutrient on track', () {
      final f = NutritionFeedbackEngine.evaluate(
        targets: targets(),
        logs: onTarget,
      );

      expect(f.allOnTrack, isTrue);
      expect(
        f.all.map((a) => a.status),
        everyElement(NutrientStatus.onTrack),
      );
    });

    test('gives a single positive insight and no warnings', () {
      final f = NutritionFeedbackEngine.evaluate(
        targets: targets(),
        logs: onTarget,
      );

      expect(f.insights, hasLength(1));
      expect(f.insights.single.tone, InsightTone.positive);
      expect(hasTitle(f, 'Well-balanced'), isTrue);
    });

    test('tolerates being within 10% of every target', () {
      final f = NutritionFeedbackEngine.evaluate(
        targets: targets(),
        // 5% under across the board.
        logs: [log(calories: 1900, protein: 71, carbs: 285, fat: 53)],
      );

      expect(f.allOnTrack, isTrue);
    });
  });

  group('energy', () {
    test('a light day reports the calories still available', () {
      final f = NutritionFeedbackEngine.evaluate(
        targets: targets(),
        // 70% of budget — under, but not under-eating.
        logs: [log(calories: 1400, protein: 53, carbs: 210, fat: 39)],
      );

      expect(f.calories.status, NutrientStatus.under);
      expect(hasTitle(f, '600 kcal left'), isTrue);
      expect(
        f.insights.first.tone,
        InsightTone.info,
        reason: 'a merely light day should not read as a warning',
      );
    });

    test('well under the budget is flagged as a warning', () {
      final f = NutritionFeedbackEngine.evaluate(
        targets: targets(),
        // 40% of budget, below the 60% under-eating threshold.
        logs: [log(calories: 800, protein: 30, carbs: 120, fat: 22)],
      );

      expect(hasTitle(f, 'Well under'), isTrue);
      expect(f.insights.first.tone, InsightTone.warning);
    });

    test('going over the budget is flagged with the excess', () {
      final f = NutritionFeedbackEngine.evaluate(
        targets: targets(),
        logs: [log(calories: 2500, protein: 94, carbs: 375, fat: 69)],
      );

      expect(f.calories.status, NutrientStatus.over);
      expect(hasTitle(f, 'Over your energy goal'), isTrue);
      expect(f.insights.first.body, contains('500 kcal'));
    });
  });

  group('macro shortfalls', () {
    test('low protein is called out even when energy is on target', () {
      final f = NutritionFeedbackEngine.evaluate(
        targets: targets(),
        // Energy on target, but protein halved and carbs picking up the slack.
        logs: [log(calories: 2000, protein: 37, carbs: 375, fat: 55.6)],
      );

      expect(f.calories.status, NutrientStatus.onTrack);
      expect(f.macros.first.status, NutrientStatus.under);
      expect(hasTitle(f, 'Protein is low'), isTrue);
    });

    test('high fat is called out', () {
      final f = NutritionFeedbackEngine.evaluate(
        targets: targets(),
        logs: [log(calories: 2000, protein: 75, carbs: 200, fat: 90)],
      );

      expect(hasTitle(f, 'Fat is running high'), isTrue);
    });
  });

  group('DOST-FNRI AMDR energy shares', () {
    test('a carb-heavy day is flagged even when calories are on target', () {
      final f = NutritionFeedbackEngine.evaluate(
        targets: targets(),
        // 1600 of 2000 kcal (80%) from carbohydrate — above the 70% ceiling.
        logs: [log(calories: 2000, protein: 75, carbs: 400, fat: 22)],
      );

      expect(f.calories.status, NutrientStatus.onTrack);
      expect(hasTitle(f, 'Carb-heavy'), isTrue);
      expect(
        f.insights.firstWhere((i) => i.title.contains('Carb-heavy')).body,
        contains('80%'),
      );
    });

    test('a fat-heavy day is flagged against the 20-30% range', () {
      final f = NutritionFeedbackEngine.evaluate(
        targets: targets(),
        // 900 of 2000 kcal (45%) from fat.
        logs: [log(calories: 2000, protein: 75, carbs: 200, fat: 100)],
      );

      expect(hasTitle(f, 'Fat share'), isTrue);
    });

    test('share advice is withheld on a nearly-empty day', () {
      final f = NutritionFeedbackEngine.evaluate(
        targets: targets(),
        // Only 300 kcal logged, and all of it carbohydrate. Too little data to
        // claim the day is carb-heavy.
        logs: [log(calories: 300, protein: 0, carbs: 75, fat: 0)],
      );

      expect(hasTitle(f, 'Carb-heavy'), isFalse);
    });
  });

  group('assessment arithmetic', () {
    test('sums across several logged items and ignores null macros', () {
      final f = NutritionFeedbackEngine.evaluate(
        targets: targets(),
        logs: [
          log(calories: 500, protein: 20, carbs: 60, fat: 15),
          log(calories: 400, protein: 15), // carbs/fat unrecorded
          log(), // an item with nothing recorded at all
        ],
      );

      expect(f.itemsLogged, 3);
      expect(f.calories.consumed, 900);
      expect(f.macros.first.consumed, 35);
      expect(f.macros[1].consumed, 60);
    });

    test('ratio, difference and progress are derived from the target', () {
      final f = NutritionFeedbackEngine.evaluate(
        targets: targets(),
        logs: [log(calories: 2400)],
      );

      expect(f.calories.ratio, closeTo(1.2, 1e-9));
      expect(f.calories.difference, closeTo(400, 1e-9));
      expect(f.calories.progress, 1.0, reason: 'progress clamps for the bar');
    });
  });

  group('unpersonalized targets', () {
    test('adds a note nudging the user to complete their profile', () {
      final f = NutritionFeedbackEngine.evaluate(
        targets: targets(personalized: false),
        logs: [log(calories: 2000, protein: 75, carbs: 300, fat: 55.6)],
      );

      expect(f.personalized, isFalse);
      expect(hasTitle(f, 'general targets'), isTrue);
      expect(f.insights.last.tone, InsightTone.info);
    });

    test('is omitted when the profile is complete', () {
      final f = NutritionFeedbackEngine.evaluate(
        targets: targets(),
        logs: [log(calories: 2000, protein: 75, carbs: 300, fat: 55.6)],
      );

      expect(hasTitle(f, 'general targets'), isFalse);
    });
  });
}
