import 'package:flutter_test/flutter_test.dart';

import 'package:foodgapp/models/nutrient_amount.dart';
import 'package:foodgapp/models/nutrition_facts.dart';
import 'package:foodgapp/models/nutrition_target.dart';
import 'package:foodgapp/models/recipe.dart';
import 'package:foodgapp/models/user_profile.dart';
import 'package:foodgapp/services/nutrition_feedback_service.dart';

/// A Spoonacular `recipes/{id}/information?includeNutrition=true` body with a
/// full nutrient breakdown.
Map<String, dynamic> _spoonacularBody() => {
      'id': 715538,
      'title': 'Chicken Adobo',
      'image': 'https://img/715538.jpg',
      'servings': 4,
      'nutrition': {
        'nutrients': [
          {'name': 'Calories', 'amount': 500.0, 'unit': 'kcal'},
          {'name': 'Fat', 'amount': 20.0, 'unit': 'g'},
          {'name': 'Saturated Fat', 'amount': 6.0, 'unit': 'g'},
          {'name': 'Carbohydrates', 'amount': 60.0, 'unit': 'g'},
          {'name': 'Fiber', 'amount': 5.0, 'unit': 'g'},
          {'name': 'Sugar', 'amount': 8.0, 'unit': 'g'},
          {'name': 'Protein', 'amount': 30.0, 'unit': 'g'},
          {'name': 'Sodium', 'amount': 1200.0, 'unit': 'mg'},
          {'name': 'Cholesterol', 'amount': 90.0, 'unit': 'mg'},
          {'name': 'Iron', 'amount': 3.0, 'unit': 'mg'},
          {'name': 'Vitamin C', 'amount': 12.0, 'unit': 'mg'},
        ],
      },
    };

/// The DOST-FNRI default target (2000 kcal), used when there's no profile.
NutritionTarget _defaultTarget() => NutritionFeedbackService.buildTarget(null);

NutritionFactRow? _row(NutritionFacts facts, String label) {
  for (final row in facts.allRows) {
    if (row.label == label) return row;
  }
  return null;
}

void main() {
  group('Recipe nutrient breakdown', () {
    test('parses the full Spoonacular breakdown and serving count', () {
      final recipe = Recipe.fromSpoonacular(_spoonacularBody());

      expect(recipe.servings, 4);
      expect(recipe.hasNutrition, isTrue);
      expect(recipe.hasDetailedNutrition, isTrue);
      expect(recipe.nutrients, hasLength(11));
      expect(recipe.nutrients.named(['Sodium'])?.amount, 1200.0);
      expect(recipe.nutrients.named(['Sodium'])?.unit, 'mg');
      // Headline macros still come through for the rest of the app.
      expect(recipe.calories, 500.0);
      expect(recipe.protein, 30.0);
    });

    test('skips malformed nutrient entries instead of failing the recipe', () {
      final body = _spoonacularBody();
      (body['nutrition']['nutrients'] as List).add({'unit': 'mg'});

      final recipe = Recipe.fromSpoonacular(body);
      expect(recipe.nutrients, hasLength(11));
      expect(recipe.calories, 500.0);
    });

    test('survives a cache round-trip with the breakdown intact', () {
      final original = Recipe.fromSpoonacular(_spoonacularBody());
      final restored = Recipe.fromCacheMap(original.toCacheMap());

      expect(restored.name, 'Chicken Adobo');
      expect(restored.servings, 4);
      expect(restored.calories, 500.0);
      expect(restored.source, 'spoonacular');
      expect(restored.imageUrl, 'https://img/715538.jpg');
      expect(restored.nutrients, hasLength(11));
      expect(restored.nutrients.named(['Fiber'])?.amount, 5.0);
    });

    test('reads rows cached before the breakdown existed', () {
      // raw_json as the previous version wrote it: no servings, no nutrients.
      final legacy = Recipe.fromCacheMap({
        'api_meal_id': 'spoonacular:1',
        'meal_name': 'Old Row',
        'calories': 300.0,
        'protein': 10.0,
        'carbs': 40.0,
        'fat': 8.0,
        'raw_json': '{"image_url":"https://img/1.jpg","source":"spoonacular"}',
        'cached_at': 0,
      });

      expect(legacy.calories, 300.0);
      expect(legacy.servings, isNull);
      expect(legacy.nutrients, isEmpty);
      expect(legacy.hasDetailedNutrition, isFalse);
    });
  });

  group('NutritionFacts.forRecipe', () {
    test('builds energy, macros, watch-list and micronutrient rows', () {
      final facts = NutritionFacts.forRecipe(
        Recipe.fromSpoonacular(_spoonacularBody()),
        target: _defaultTarget(),
      );

      expect(facts.hasData, isTrue);
      expect(facts.hasBreakdown, isTrue);
      expect(facts.foodName, 'Chicken Adobo');
      expect(facts.recipeServings, 4);
      expect(facts.energy?.amount, 500.0);
      expect(
        facts.macros.map((r) => r.label),
        [
          'Carbohydrates',
          'Dietary fibre',
          'Sugars',
          'Protein',
          'Fat',
          'Saturated fat'
        ],
      );
      expect(facts.details.map((r) => r.label), ['Sodium', 'Cholesterol']);
      expect(facts.micronutrients.map((r) => r.label), ['Iron', 'Vitamin C']);
    });

    test('shows energy and macros as a share of the daily target', () {
      final facts = NutritionFacts.forRecipe(
        Recipe.fromSpoonacular(_spoonacularBody()),
        target: _defaultTarget(),
      );

      // Defaults are 2000 kcal, so 500 kcal is a quarter of the day.
      expect(facts.energy?.dailyPercent, 25);
      // Protein target mid-point is 12.5% of 2000 kcal / 4 = 62.5 g.
      expect(_row(facts, 'Protein')?.dailyReference, 62.5);
      expect(_row(facts, 'Protein')?.dailyPercent, 48);
    });

    test('flags a nutrient that blows past its daily limit', () {
      final facts = NutritionFacts.forRecipe(
        Recipe.fromSpoonacular(_spoonacularBody()),
        target: _defaultTarget(),
      );

      final sodium = _row(facts, 'Sodium')!;
      expect(sodium.referenceKind, DailyReferenceKind.limit);
      expect(sodium.dailyReference, 2000.0);
      expect(sodium.dailyPercent, 60);
      expect(sodium.exceedsLimit, isFalse);

      // Two servings puts sodium past the 2000 mg/day limit.
      final twoServings = NutritionFacts.forRecipe(
        Recipe.fromSpoonacular(_spoonacularBody()),
        target: _defaultTarget(),
        servingsShown: 2,
      );
      expect(_row(twoServings, 'Sodium')!.exceedsLimit, isTrue);
    });

    test('leaves micronutrients without a daily reference', () {
      final facts = NutritionFacts.forRecipe(
        Recipe.fromSpoonacular(_spoonacularBody()),
        target: _defaultTarget(),
      );

      final iron = _row(facts, 'Iron')!;
      expect(iron.amount, 3.0);
      expect(iron.unit, 'mg');
      expect(iron.dailyReference, isNull);
      expect(iron.dailyShare, isNull);
    });

    test('scales every value by the serving count', () {
      final recipe = Recipe.fromSpoonacular(_spoonacularBody());
      final facts = NutritionFacts.forRecipe(
        recipe,
        target: _defaultTarget(),
        servingsShown: 3,
      );

      expect(facts.servingsShown, 3);
      expect(facts.energy?.amount, 1500.0);
      expect(_row(facts, 'Carbohydrates')?.amount, 180.0);
      expect(_row(facts, 'Dietary fibre')?.amount, 15.0);
      expect(_row(facts, 'Iron')?.amount, 9.0);
      // The reference stays a whole day's worth; only intake scales.
      expect(facts.energy?.dailyReference, 2000.0);
      expect(facts.energy?.dailyPercent, 75);
    });

    test('omits rows for nutrients the source never reported', () {
      // findByNutrients results carry the four macros and nothing else.
      final recipe = Recipe.fromSpoonacularNutrients({
        'id': 123,
        'title': 'Boiled Egg',
        'calories': 155,
        'protein': '13g',
        'carbs': '1g',
        'fat': '11g',
      });

      final facts = NutritionFacts.forRecipe(recipe, target: _defaultTarget());

      expect(facts.hasData, isTrue);
      expect(facts.hasBreakdown, isFalse);
      expect(facts.energy?.amount, 155.0);
      expect(_row(facts, 'Protein')?.amount, 13.0);
      // Nothing reported these, so they aren't shown as zero.
      expect(_row(facts, 'Sodium'), isNull);
      expect(_row(facts, 'Dietary fibre'), isNull);
    });

    test('reports no data for a TheMealDB result', () {
      final recipe = Recipe.fromTheMealDb({
        'idMeal': '52772',
        'strMeal': 'Teriyaki Chicken',
        'strMealThumb': 'https://img/52772.jpg',
      });

      final facts = NutritionFacts.forRecipe(recipe, target: _defaultTarget());

      expect(facts.hasData, isFalse);
      expect(facts.energy, isNull);
      expect(facts.macros, isEmpty);
      expect(facts.foodName, 'Teriyaki Chicken');
    });

    test('marks the panel personalised only when the profile drove it', () {
      final recipe = Recipe.fromSpoonacular(_spoonacularBody());

      final defaults =
          NutritionFacts.forRecipe(recipe, target: _defaultTarget());
      expect(defaults.personalised, isFalse);

      final withProfile = NutritionFacts.forRecipe(
        recipe,
        target: NutritionFeedbackService.buildTarget(
          const UserProfile(
            userId: 'u1',
            age: 25,
            gender: 'female',
            heightCm: 160,
            weightKg: 55,
            activityLevel: 'moderately active',
          ),
        ),
      );
      expect(withProfile.personalised, isTrue);
    });
  });
}
