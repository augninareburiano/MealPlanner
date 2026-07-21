import '../models/nutrition_facts.dart';
import '../models/nutrition_target.dart';
import '../models/recipe.dart';
import 'database_helper.dart';
import 'nutrition_feedback_service.dart';
import 'recipe_repository.dart';

/// A food or meal with everything needed to show its nutritional values: the
/// resolved recipe and the daily target to compare it against.
///
/// The two are kept together so changing the serving count on screen rebuilds
/// the panel locally — no second API call, no second profile read.
class ResolvedNutrition {
  final Recipe recipe;
  final NutritionTarget target;

  const ResolvedNutrition({required this.recipe, required this.target});

  NutritionFacts factsFor(double servings) => NutritionFacts.forRecipe(
        recipe,
        target: target,
        servingsShown: servings,
      );
}

/// Backs the nutrition facts feature: search foods and meals, then show their
/// nutritional values against the user's DOST-FNRI daily target.
///
/// Search and per-recipe nutrition come from [RecipeRepository] (Spoonacular
/// primary, TheMealDB backup, SQLite cache in front of both), so repeat
/// lookups of the same food don't spend API quota.
class NutritionFactsService {
  NutritionFactsService({RecipeRepository? repository, DatabaseHelper? db})
      : _repository = repository ?? RecipeRepository(),
        _db = db ?? DatabaseHelper.instance;

  final RecipeRepository _repository;
  final DatabaseHelper _db;

  /// True when the app can actually report nutritional values. False means no
  /// Spoonacular key is configured, so searches fall back to name-only results.
  bool get hasNutritionSource => _repository.hasNutritionSource;

  /// Searches foods and meals by name. Returns `[]` rather than throwing when
  /// both sources are unavailable.
  Future<List<Recipe>> search(String query) => _repository.searchByName(query);

  /// Resolves the full nutritional values for [recipe] and the daily target to
  /// read them against.
  ///
  /// Search results already carry a breakdown when they came from Spoonacular;
  /// when they don't (a TheMealDB result, or a cached macros-only row) this
  /// asks the repository for the detail, keeping whatever the search gave us
  /// if nothing better is available.
  Future<ResolvedNutrition> resolve({
    required Recipe recipe,
    required String userId,
  }) async {
    var resolved = recipe;
    if (!recipe.hasDetailedNutrition) {
      final detailed = await _repository.getNutrition(recipe.apiMealId);
      if (detailed != null && detailed.hasDetailedNutrition) {
        resolved = detailed;
      }
    }

    final profile = await _db.getUserProfile(userId);
    return ResolvedNutrition(
      recipe: resolved,
      target: NutritionFeedbackService.buildTarget(profile),
    );
  }

  void dispose() => _repository.dispose();
}
